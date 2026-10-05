import CoreMedia
import Foundation
import Network

private let insta360Queue = DispatchQueue(label: "com.eerimoq.moblin.insta360")

enum Insta360ClientState: Sendable {
    case disconnected
    case connecting
    case waitingForVideo
    case streaming
    case retrying

    func toString() -> String {
        switch self {
        case .disconnected:
            String(localized: "Disconnected")
        case .connecting:
            String(localized: "Connecting")
        case .waitingForVideo:
            String(localized: "Waiting for video")
        case .streaming:
            String(localized: "Receiving video")
        case .retrying:
            String(localized: "Reconnecting")
        }
    }
}

protocol Insta360ClientDelegate: AnyObject {
    func insta360Client(_ client: Insta360Client, stateChanged state: Insta360ClientState)
    func insta360Client(_ client: Insta360Client, videoBuffer: CMSampleBuffer)
}

class Insta360Client: @unchecked Sendable {
    let cameraId: UUID
    private let host: String
    private let port: UInt16
    private let latency: Double
    private let softwareDecoding: Bool
    private let colorRange: SettingsStreamColorRange
    private weak var delegate: (any Insta360ClientDelegate)?
    private var connection: NWConnection?
    private var parser = Insta360Protocol()
    private var hevc = Insta360HevcStream()
    private var state: Insta360ClientState = .disconnected
    private var started = false
    private var previewRequested = false
    private var reconnectDelay = 2.0
    private let timeoutTimer = SimpleTimer(queue: insta360Queue)
    private let keepAliveTimer = SimpleTimer(queue: insta360Queue)
    private let reconnectTimer = SimpleTimer(queue: insta360Queue)
    private var lastFrameAt = 0.0
    private var lastPresentationTimeStamp = 0.0
    private var bitrateStats = BitrateStats()
    private var parameterSets: [UInt8: Data] = [:]
    private var formatDescription: CMFormatDescription?
    private var decoder: VideoDecoder?
    private var receivedKeyframe = false

    init(cameraId: UUID,
         host: String,
         port: UInt16 = 6666,
         latency: Double,
         softwareDecoding: Bool,
         colorRange: SettingsStreamColorRange,
         delegate: any Insta360ClientDelegate)
    {
        self.cameraId = cameraId
        self.host = host
        self.port = port
        self.latency = latency
        self.softwareDecoding = softwareDecoding
        self.colorRange = colorRange
        self.delegate = delegate
    }

    func start() {
        insta360Queue.async {
            guard !self.started else {
                return
            }
            self.started = true
            self.connect()
        }
    }

    func stop() {
        insta360Queue.async {
            self.started = false
            self.reconnectTimer.stop()
            self.closeConnection()
            self.setState(.disconnected)
        }
    }

    func updateStats() -> BitrateStatsInstant {
        insta360Queue.sync {
            bitrateStats.update()
        }
    }

    private func setState(_ state: Insta360ClientState) {
        guard state != self.state else {
            return
        }
        self.state = state
        delegate?.insta360Client(self, stateChanged: state)
    }

    private func connect() {
        guard started, let port = NWEndpoint.Port(rawValue: port) else {
            return
        }
        setState(.connecting)
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.prohibitExpensivePaths = true
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: parameters)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection, connection === self.connection else {
                return
            }
            switch state {
            case .ready:
                beginSession(connection)
            case let .failed(error), let .waiting(error):
                fail("Connection failed: \(error)")
            default:
                break
            }
        }
        timeoutTimer.startSingleShot(timeout: 10) { [weak self] in
            self?.fail("Connection or handshake timed out")
        }
        connection.start(queue: insta360Queue)
    }

    private func beginSession(_ connection: NWConnection) {
        lastFrameAt = ProcessInfo.processInfo.systemUptime
        receive(connection)
        send(Insta360Protocol.frame(Insta360Protocol.syncPayload), on: connection)
        send(Insta360Protocol.frame(Data([5, 0, 0])), on: connection)
        keepAliveTimer.startPeriodic(interval: 2) { [weak self, weak connection] in
            guard let self, let connection, connection === self.connection else {
                return
            }
            guard ProcessInfo.processInfo.systemUptime - lastFrameAt < 12 else {
                fail("No decoded video received for 12 seconds")
                return
            }
            send(Insta360Protocol.frame(Data([5, 0, 0])), on: connection)
        }
    }

    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 128 * 1024) {
            [weak self, weak connection] data, _, complete, error in
            guard let self, let connection, connection === self.connection else {
                return
            }
            if let data, !data.isEmpty {
                bitrateStats.add(bytesTransferred: data.count)
                do {
                    for packet in try parser.append(data) {
                        try handle(packet, connection: connection)
                        guard connection === self.connection else {
                            return
                        }
                    }
                } catch {
                    fail("Invalid camera stream: \(error)")
                    return
                }
            }
            if let error {
                fail("Receive failed: \(error)")
            } else if complete {
                fail("Camera closed the connection")
            } else {
                receive(connection)
            }
        }
    }

    private func handle(_ packet: Insta360Packet, connection: NWConnection) throws {
        switch packet {
        case .sync:
            guard !previewRequested else {
                return
            }
            timeoutTimer.stop()
            previewRequested = true
            setState(.waitingForVideo)
            send(Insta360Protocol.command(id: 1, sequence: 0), on: connection)
        case let .response(code, sequence):
            if sequence == 0, code >= 400, code < 600 {
                fail("Camera rejected the preview request with status \(code)")
            }
        case let .video(data):
            guard previewRequested else {
                return
            }
            for frame in try hevc.append(data) {
                decode(frame)
            }
        case .keepAlive, .unknown:
            break
        }
    }

    private func send(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { [weak self, weak connection] error in
            guard let self, let connection, connection === self.connection, let error else {
                return
            }
            fail("Send failed: \(error)")
        })
    }

    private func fail(_ reason: String) {
        guard started, connection != nil else {
            return
        }
        logger.info("insta360: \(reason)")
        closeConnection()
        setState(.retrying)
        reconnectTimer.startSingleShot(timeout: reconnectDelay) { [weak self] in
            self?.connect()
        }
        reconnectDelay = min(reconnectDelay * 2, 15)
    }

    private func closeConnection() {
        timeoutTimer.stop()
        keepAliveTimer.stop()
        let oldConnection = connection
        connection = nil
        oldConnection?.stateUpdateHandler = nil
        if previewRequested, let oldConnection, oldConnection.state == .ready {
            oldConnection.send(content: Insta360Protocol.command(id: 2, sequence: 1),
                               completion: .contentProcessed { _ in oldConnection.cancel() })
            insta360Queue.asyncAfter(deadline: .now() + 1) {
                oldConnection.cancel()
            }
        } else {
            oldConnection?.cancel()
        }
        decoder?.stopRunning()
        decoder = nil
        formatDescription = nil
        parameterSets = [:]
        parser = .init()
        hevc = .init()
        receivedKeyframe = false
        previewRequested = false
        lastPresentationTimeStamp = 0
    }

    private func decode(_ frame: Insta360HevcFrame) {
        for nalUnit in frame.nalUnits {
            let type = (nalUnit[0] >> 1) & 0x3F
            if (32 ... 34).contains(type), parameterSets[type] != nalUnit {
                parameterSets[type] = nalUnit
                formatDescription = nil
                receivedKeyframe = false
            }
        }
        if formatDescription == nil {
            guard let description = makeFormatDescription() else {
                return
            }
            decoder?.stopRunning()
            decoder = VideoDecoder(name: "insta360", lockQueue: insta360Queue,
                                   softwareDecoding: softwareDecoding, colorRange: colorRange)
            decoder?.delegate = self
            decoder?.startRunning(formatDescription: description)
            formatDescription = description
        }
        if frame.isKeyframe {
            receivedKeyframe = true
        }
        guard receivedKeyframe, let formatDescription else {
            return
        }
        let timestamp = max(currentPresentationTimeStamp().seconds + latency,
                            lastPresentationTimeStamp + 0.001)
        lastPresentationTimeStamp = timestamp
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMTime(seconds: timestamp),
                                        decodeTimeStamp: .invalid)
        let data = frame.lengthPrefixedData()
        guard let blockBuffer = data.makeBlockBuffer() else {
            return
        }
        var size = data.count
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: blockBuffer,
                                               formatDescription: formatDescription, sampleCount: 1,
                                               sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                               sampleSizeEntryCount: 1, sampleSizeArray: &size,
                                               sampleBufferOut: &sampleBuffer)
        guard status == noErr, let sampleBuffer else {
            return
        }
        sampleBuffer.setIsSync(frame.isKeyframe)
        decoder?.decodeSampleBuffer(sampleBuffer)
    }

    private func makeFormatDescription() -> CMFormatDescription? {
        guard let vps = parameterSets[32], let sps = parameterSets[33], let pps = parameterSets[34] else {
            return nil
        }
        return vps.withUnsafeBytes { vpsBytes in
            sps.withUnsafeBytes { spsBytes in
                pps.withUnsafeBytes { ppsBytes in
                    let pointers = [vpsBytes, spsBytes, ppsBytes].map {
                        $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    }
                    var description: CMFormatDescription?
                    let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault, parameterSetCount: 3, parameterSetPointers: pointers,
                        parameterSetSizes: [vps.count, sps.count, pps.count], nalUnitHeaderLength: 4,
                        extensions: nil, formatDescriptionOut: &description
                    )
                    return status == noErr ? description : nil
                }
            }
        }
    }
}

extension Insta360Client: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_ codec: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        guard started, connection != nil, codec === decoder else {
            return
        }
        lastFrameAt = ProcessInfo.processInfo.systemUptime
        reconnectDelay = 2
        setState(.streaming)
        delegate?.insta360Client(self, videoBuffer: sampleBuffer)
    }
}
