import AVFoundation
import CoreMedia
import Foundation
import HaishinKit
import Network
import RTCHaishinKit

let whipServerDispatchQueue = DispatchQueue(label: "com.eerimoq.whip-server")

protocol WhipServerDelegate: AnyObject {
    func whipServerOnPublishStart(streamKey: String)
    func whipServerOnPublishStop(streamKey: String, reason: String)
    func whipServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whipServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
}

/// Handles audio from IncomingStream (Opus → PCM via AudioCodec) and retimes PTS.
/// Video is handled separately by WhipServerVideoDecoder via onCompressedVideo.
private final class WhipServerAudioOutput: StreamOutput, @unchecked Sendable {
    private let cameraId: UUID
    private weak var delegate: (any WhipServerDelegate)?
    private let latency: Double
    private let lock = NSLock()
    private var audioBasePts: Double = -1
    private var firstAudioPts: Double = -1

    init(cameraId: UUID, delegate: (any WhipServerDelegate)?, latency: Double) {
        self.cameraId = cameraId
        self.delegate = delegate
        self.latency = latency
    }

    func stream(_ stream: some StreamConvertible, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
        guard let audio = audio as? AVAudioPCMBuffer else {
            return
        }
        let audioSeconds = AVAudioTime.seconds(forHostTime: when.hostTime)
        lock.lock()
        if audioBasePts < 0 {
            audioBasePts = currentPresentationTimeStamp().seconds
            firstAudioPts = audioSeconds
        }
        let newPtsSeconds = audioBasePts + (audioSeconds - firstAudioPts) + latency
        lock.unlock()
        let pts = CMTime(seconds: newPtsSeconds, preferredTimescale: 1_000_000_000)
        guard let sampleBuffer = audio.makeSampleBuffer(pts) else {
            return
        }
        delegate?.whipServerOnAudioBuffer(cameraId: cameraId, sampleBuffer)
    }

    func stream(_: some StreamConvertible, didOutput _: CMSampleBuffer) {
        // Video is handled by WhipServerVideoDecoder, not through RTCStream outputs.
    }
}

/// Decodes compressed H264 video from RTCTrack and delivers decoded frames to
/// BufferedVideo. Matches the RTMP server approach: retime PTS BEFORE decode,
/// use Moblin's VideoDecoder, direct delivery — no MediaLink or IncomingStream.
private final class WhipServerVideoDecoder: @unchecked Sendable {
    private let cameraId: UUID
    private weak var delegate: (any WhipServerDelegate)?
    private let latency: Double
    private let lockQueue = DispatchQueue(label: "com.eerimoq.whip-video-decoder")
    private let decoder: VideoDecoder
    private var basePts: Double = -1
    private var firstFramePts: Double = -1
    private var lastOutputPts: Double = -1
    private var currentFormatDescription: CMFormatDescription?

    init(cameraId: UUID, delegate: (any WhipServerDelegate)?, latency: Double) {
        self.cameraId = cameraId
        self.delegate = delegate
        self.latency = latency
        decoder = VideoDecoder(lockQueue: lockQueue)
    }

    func start() {
        decoder.delegate = self
    }

    func stop() {
        decoder.stopRunning()
    }

    /// Called from the RTCTrack callback thread with compressed H264 CMSampleBuffer.
    func handleCompressedVideo(_ buffer: CMSampleBuffer) {
        lockQueue.async { [weak self] in
            self?.handleCompressedVideoInternal(buffer)
        }
    }

    private func handleCompressedVideoInternal(_ buffer: CMSampleBuffer) {
        // Update decoder session when format description changes (new SPS/PPS).
        // Use setFormatDescriptionSync so the format description is available
        // IMMEDIATELY for the decodeSampleBuffer call below (same queue).
        if let fd = buffer.formatDescription, fd != currentFormatDescription {
            currentFormatDescription = fd
            decoder.setFormatDescriptionSync(fd)
        }

        // Retime PTS before decode (matches RTMP server approach).
        let framePts = buffer.presentationTimeStamp.seconds
        if basePts < 0 {
            basePts = currentPresentationTimeStamp().seconds
            firstFramePts = framePts
        }
        var newPtsSeconds = basePts + (framePts - firstFramePts) + latency
        if newPtsSeconds <= lastOutputPts {
            newPtsSeconds = lastOutputPts + 0.001
        }
        lastOutputPts = newPtsSeconds

        // Discard stale frames whose PTS is already in the past.
        // This prevents burst playback of accumulated frames after decode errors.
        let now = currentPresentationTimeStamp().seconds
        if newPtsSeconds < now - 0.1 {
            // Frame is more than 100ms in the past — skip it.
            // Reset base PTS so the next frame starts fresh relative to "now".
            basePts = -1
            firstFramePts = -1
            lastOutputPts = -1
            return
        }

        let newPts = CMTime(seconds: newPtsSeconds, preferredTimescale: 1_000_000_000)
        if let retimed = buffer.replacePresentationTimeStamp(newPts) {
            decoder.decodeSampleBuffer(retimed)
        }
    }
}

extension WhipServerVideoDecoder: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        delegate?.whipServerOnVideoBuffer(cameraId: cameraId, sampleBuffer)
    }
}

private final class WhipServerSession: NSObject, RTCPeerConnectionDelegate {
    let streamKey: String
    let cameraId: UUID
    let peerConnection: RTCPeerConnection
    let stream: RTCStream
    let videoDecoder: WhipServerVideoDecoder
    weak var delegate: (any WhipServerDelegate)?
    private let onTerminated: @Sendable () -> Void
    private var terminated = false
    private var didConnect = false
    private var pendingTerminateWorkItem: DispatchWorkItem?
    private let localCandidatesLock = NSLock()
    private var localCandidates: [RTCIceCandidate] = []

    init(
        streamKey: String,
        cameraId: UUID,
        peerConnection: RTCPeerConnection,
        stream: RTCStream,
        videoDecoder: WhipServerVideoDecoder,
        delegate: (any WhipServerDelegate)?,
        onTerminated: @escaping @Sendable () -> Void
    ) {
        self.streamKey = streamKey
        self.cameraId = cameraId
        self.peerConnection = peerConnection
        self.stream = stream
        self.videoDecoder = videoDecoder
        self.delegate = delegate
        self.onTerminated = onTerminated
        super.init()
        peerConnection.delegate = self
        peerConnection.attachIncomingStream(stream)
    }

    func close(reason: String) {
        terminate(reason: reason)
        videoDecoder.stop()
        peerConnection.close()
        Task { await stream.close() }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, connectionStateChanged connectionState: RTCPeerConnection.ConnectionState) {
        logger.info("whip-server: \(streamKey) state=\(connectionState)")
        switch connectionState {
        case .connected:
            didConnect = true
            pendingTerminateWorkItem?.cancel()
            pendingTerminateWorkItem = nil
            delegate?.whipServerOnPublishStart(streamKey: streamKey)
        case .closed, .failed, .disconnected:
            // Some WHIP clients (e.g. ffmpeg) send 0 candidates in the initial offer and then trickle via PATCH.
            // libdatachannel may temporarily report a failed/disconnected state before remote candidates arrive.
            // Give it a short grace period before tearing down the session.
            if didConnect {
                terminate(reason: "\(connectionState)")
            } else {
                pendingTerminateWorkItem?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    self.terminate(reason: "\(connectionState)")
                }
                pendingTerminateWorkItem = work
                whipServerDispatchQueue.asyncAfter(deadline: .now() + 3.0, execute: work)
            }
        default:
            break
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, iceGatheringStateChanged iceGatheringState: RTCPeerConnection.IceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, iceConnectionStateChanged iceConnectionState: RTCPeerConnection.IceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, signalingStateChanged signalingState: RTCPeerConnection.SignalingState) {}
    func peerConnection(_ peerConneciton: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, gotIceCandidate candidated: RTCIceCandidate) {
        let line = candidated.candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else {
            return
        }
        let lower = line.lowercased()
        if lower.contains(" tcp ") || lower.contains(" fe80:") {
            return
        }
        logger.info("whip-server: \(streamKey) local-candidate mid=\(candidated.mid) \(line)")
        localCandidatesLock.lock()
        localCandidates.append(candidated)
        localCandidatesLock.unlock()
    }

    func getLocalCandidates() -> [RTCIceCandidate] {
        localCandidatesLock.lock()
        defer { localCandidatesLock.unlock() }
        return localCandidates
    }

    private func terminate(reason: String) {
        guard !terminated else {
            return
        }
        terminated = true
        delegate?.whipServerOnPublishStop(streamKey: streamKey, reason: reason)
        onTerminated()
    }
}

final class WhipServer {
    weak var delegate: (any WhipServerDelegate)?
    var settings: SettingsWhipServer

    private let httpServer: HttpServer
    private var sessionsByStreamKey: [String: WhipServerSession] = [:]

    init(settings: SettingsWhipServer) {
        self.settings = settings
        httpServer = HttpServer(queue: whipServerDispatchQueue, routes: [])
        rebuildRoutes()
    }

    func start() {
        rebuildRoutes()
        httpServer.start(port: NWEndpoint.Port(rawValue: settings.port) ?? .http)
    }

    func stop() {
        whipServerDispatchQueue.async {
            self.httpServer.stop()
            for (_, session) in self.sessionsByStreamKey {
                session.close(reason: "Server stop")
            }
            self.sessionsByStreamKey.removeAll()
        }
    }

    func isStreamConnected(streamKey: String) -> Bool {
        whipServerDispatchQueue.sync {
            sessionsByStreamKey[streamKey] != nil
        }
    }

    private func rebuildRoutes() {
        var routes: [HttpServerRoute] = []
        for stream in settings.streams {
            let path = "/whip/\(stream.streamKey)"
            routes.append(HttpServerRoute(path: path) { [weak self] request, response in
                self?.handleRequest(stream: stream, request: request, response: response)
            })
        }
        httpServer.setRoutes(routes)
    }

    private func handleRequest(stream: SettingsWhipServerStream, request: HttpServerRequest, response: HttpServerResponse) {
        switch request.method.uppercased() {
        case "POST":
            handlePost(stream: stream, request: request, response: response)
        case "PATCH":
            handlePatch(stream: stream, request: request, response: response)
        case "DELETE":
            handleDelete(stream: stream, response: response)
        default:
            response.send(text: "", status: .methodNotAllowed)
        }
    }

    private func handleDelete(stream: SettingsWhipServerStream, response: HttpServerResponse) {
        whipServerDispatchQueue.async {
            if let session = self.sessionsByStreamKey[stream.streamKey] {
                session.close(reason: "Client delete")
                self.sessionsByStreamKey[stream.streamKey] = nil
            }
            response.send(text: "", status: .ok)
        }
    }

    private func handlePatch(stream: SettingsWhipServerStream, request: HttpServerRequest, response: HttpServerResponse) {
        // Trickle ICE: application/trickle-ice-sdpfrag (RFC 8840)
        whipServerDispatchQueue.async {
            guard let session = self.sessionsByStreamKey[stream.streamKey] else {
                response.send(text: "", status: .notFound)
                return
            }
            guard let frag = String(data: request.body, encoding: .utf8), !frag.isEmpty else {
                response.send(text: "", status: .badRequest)
                return
            }
            do {
                let (candidates, mid) = Self.parseTrickleIceSdpFrag(frag)
                logger.info("whip-server: patch streamKey=\(stream.streamKey) mid=\(mid ?? "-") candidates=\(candidates.count)")
                for candidate in candidates {
                    try session.peerConnection.addRemoteCandidate(candidate, mid: mid)
                }
                response.send(text: "", status: .noContent)
            } catch {
                logger.info("whip-server: patch error: \(error)")
                response.send(text: "", status: .badRequest)
            }
        }
    }

    private func handlePost(stream: SettingsWhipServerStream, request: HttpServerRequest, response: HttpServerResponse) {
        if let contentType = request.header("content-type"), !contentType.hasPrefix("application/sdp") {
            response.send(text: "", status: .unsupportedMediaType)
            return
        }
        guard let offer = String(data: request.body, encoding: .utf8), !offer.isEmpty else {
            response.send(text: "", status: .badRequest)
            return
        }
        whipServerDispatchQueue.async {
            if let existing = self.sessionsByStreamKey[stream.streamKey] {
                existing.close(reason: "Replaced by new publisher")
                self.sessionsByStreamKey[stream.streamKey] = nil
            }
            Task {
                do {
                    let (sanitizedOffer, removedCandidates) = Self.sanitizeOfferSdp(offer)
                    logger.info(
                        "whip-server: received offer for \(stream.streamKey) (\(offer.count) bytes), " +
                            "candidates=\(Self.countCandidates(offer)), removedCandidates=\(removedCandidates)"
                    )
                    let latency = min(Double(stream.latency) / 1000.0, 0.5)

                    // --- Video path (RTMP-style): compressed RTP → retime PTS → VideoDecoder → BufferedVideo ---
                    let videoDecoder = WhipServerVideoDecoder(
                        cameraId: stream.id,
                        delegate: self.delegate,
                        latency: latency
                    )
                    videoDecoder.start()

                    // --- Audio path: RTCTrack → IncomingStream/AudioCodec (Opus→PCM) → WhipServerAudioOutput ---
                    let rtcStream = RTCStream()
                    await rtcStream.setDirection(.recvonly)
                    await rtcStream.addOutput(WhipServerAudioOutput(
                        cameraId: stream.id,
                        delegate: self.delegate,
                        latency: latency
                    ))

                    let peerConnection = try RTCPeerConnection(RTCConfiguration())
                    // Set onCompressedVideo BEFORE setRemoteDescription so that when
                    // libdatachannel fires the track callback, video tracks are routed
                    // to our VideoDecoder. Audio tracks go to incomingStream (RTCStream).
                    peerConnection.onCompressedVideo = { [weak videoDecoder] buffer in
                        videoDecoder?.handleCompressedVideo(buffer)
                    }
                    peerConnection.attachIncomingStream(rtcStream)
                    let session = WhipServerSession(
                        streamKey: stream.streamKey,
                        cameraId: stream.id,
                        peerConnection: peerConnection,
                        stream: rtcStream,
                        videoDecoder: videoDecoder,
                        delegate: self.delegate,
                        onTerminated: { [weak self] in
                            whipServerDispatchQueue.async {
                                self?.sessionsByStreamKey[stream.streamKey] = nil
                            }
                        }
                    )

                    try peerConnection.setRemoteDesciption(sanitizedOffer, type: .offer)
                    let answer = await self.waitForLocalDescription(peerConnection: peerConnection, timeoutSeconds: 2.0)
                    await self.waitForIceGatheringComplete(peerConnection: peerConnection, timeoutSeconds: 5.0)

                    // libdatachannel may not embed gathered candidates into the local SDP string
                    // even when gathering is complete (trickle-only behavior). WHIP endpoints must
                    // include their ICE candidates in the SDP answer, so we inject candidates that
                    // arrive via the local-candidate callback.
                    let baseAnswer = peerConnection.localDescriptionSdp.isEmpty ? answer : peerConnection.localDescriptionSdp
                    let injected = Self.injectCandidatesIntoAnswerSdp(
                        baseAnswer,
                        candidates: session.getLocalCandidates()
                    )
                    let finalAnswer = injected
                    guard !finalAnswer.isEmpty else {
                        throw RTCError.notAvail
                    }
                    logger.info(
                        "whip-server: generated answer for \(stream.streamKey) (\(finalAnswer.count) bytes), " +
                            "iceGathering=\(peerConnection.iceGatheringState), candidates=\(Self.countCandidates(finalAnswer))"
                    )

                    whipServerDispatchQueue.async {
                        self.sessionsByStreamKey[stream.streamKey] = session
                        let path = "/whip/\(stream.streamKey)"
                        let location: String
                        if let host = request.header("host"), !host.isEmpty {
                            location = "http://\(host)\(path)"
                        } else {
                            location = path
                        }
                        response.send(
                            text: finalAnswer,
                            status: .created,
                            contentType: "application/sdp",
                            headers: [("Location", location)]
                        )
                    }
                } catch {
                    logger.info("whip-server: \(error)")
                    response.send(text: "", status: .internalServerError)
                }
            }
        }
    }

    private func waitForIceGatheringComplete(peerConnection: RTCPeerConnection, timeoutSeconds: Double) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while peerConnection.iceGatheringState != .complete && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func waitForLocalDescription(peerConnection: RTCPeerConnection, timeoutSeconds: Double) async -> String {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while peerConnection.localDescriptionSdp.isEmpty && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(25))
        }
        return peerConnection.localDescriptionSdp
    }

    private static func parseTrickleIceSdpFrag(_ frag: String) -> (candidates: [String], mid: String?) {
        var candidates: [String] = []
        var mid: String?
        for rawLine in frag.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("a=mid:") {
                mid = String(line.dropFirst("a=mid:".count))
            } else if line.hasPrefix("a=candidate:") || line.hasPrefix("candidate:") {
                // Heuristic: libdatachannel often can't send to IPv6 link-local candidates (missing scope),
                // and TCP candidates are not useful for our LAN ingest use-case.
                let lower = line.lowercased()
                if lower.contains(" tcp ") || lower.contains(" fe80:") {
                    continue
                }
                candidates.append(line)
            }
        }
        return (candidates, mid)
    }

    private static func countCandidates(_ sdp: String) -> Int {
        return sdp.split(separator: "\n").filter {
            let line = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return line.hasPrefix("a=candidate:") || line.hasPrefix("candidate:")
        }.count
    }

    private static func sanitizeOfferSdp(_ offer: String) -> (sdp: String, removedCandidates: Int) {
        var removed = 0
        let lines = offer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let kept: [String] = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("a=candidate:") else {
                return true
            }
            let lower = trimmed.lowercased()
            if lower.contains(" tcp ") || lower.contains(" fe80:") {
                removed += 1
                return false
            }
            return true
        }
        return (kept.joined(separator: "\n"), removed)
    }

    private static func injectCandidatesIntoAnswerSdp(_ sdp: String, candidates: [RTCIceCandidate]) -> String {
        guard !sdp.isEmpty, !candidates.isEmpty else {
            return sdp
        }
        // If SDP already contains candidates, keep it (avoid duplicates).
        if countCandidates(sdp) > 0 {
            return sdp
        }

        var lines = sdp.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let mediaStarts = lines.indices.filter { lines[$0].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("m=") }
        guard let firstMediaStart = mediaStarts.first else {
            // No media sections; just append at end best-effort.
            var appended = lines
            for c in candidates {
                let l = normalizeCandidateLine(c.candidate)
                if !l.isEmpty { appended.append(l) }
            }
            appended.append("a=end-of-candidates")
            return appended.joined(separator: "\n")
        }

        // Map mid -> insertion section (start index of that m= section).
        var sectionByMid: [String: Int] = [:]
        for i in 0..<mediaStarts.count {
            let start = mediaStarts[i]
            let end = (i + 1 < mediaStarts.count) ? mediaStarts[i + 1] : lines.count
            for j in start..<end {
                let t = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                if t.hasPrefix("a=mid:") {
                    let mid = String(t.dropFirst("a=mid:".count))
                    sectionByMid[mid] = start
                    break
                }
            }
        }

        // Group candidates by section start.
        var candidatesBySection: [Int: [String]] = [:]
        for c in candidates {
            let line = normalizeCandidateLine(c.candidate)
            if line.isEmpty { continue }
            let section = sectionByMid[c.mid] ?? firstMediaStart
            candidatesBySection[section, default: []].append(line)
        }

        // Insert from bottom to top to keep indices valid.
        let sortedSections = candidatesBySection.keys.sorted(by: >)
        for sectionStart in sortedSections {
            guard let insertLines = candidatesBySection[sectionStart], !insertLines.isEmpty else { continue }

            let sectionIndex = mediaStarts.firstIndex(of: sectionStart) ?? 0
            let sectionEnd = (sectionIndex + 1 < mediaStarts.count) ? mediaStarts[sectionIndex + 1] : lines.count

            // Insert near end of section, before next m=.
            var insertAt = sectionEnd
            // Keep end-of-candidates inside section.
            let alreadyHasEnd = lines[sectionStart..<sectionEnd].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "a=end-of-candidates" }
            if alreadyHasEnd {
                // Insert before end-of-candidates line if present.
                if let idx = (sectionStart..<sectionEnd).firstIndex(where: {
                    $0 >= 0 && lines[$0].trimmingCharacters(in: .whitespacesAndNewlines) == "a=end-of-candidates"
                }) {
                    insertAt = idx
                }
            }

            lines.insert(contentsOf: insertLines, at: insertAt)
            if !alreadyHasEnd {
                lines.insert("a=end-of-candidates", at: insertAt + insertLines.count)
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func normalizeCandidateLine(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if trimmed.hasPrefix("a=candidate:") { return trimmed }
        if trimmed.hasPrefix("candidate:") { return "a=\(trimmed)" }
        if trimmed.contains("candidate:") {
            // Best effort: ensure it's an SDP attribute.
            return trimmed.hasPrefix("a=") ? trimmed : "a=\(trimmed)"
        }
        return ""
    }
}

