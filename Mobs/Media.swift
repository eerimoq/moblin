import AVFoundation
import HaishinKit
import SRTHaishinKit

let mediaDispatchQueue = DispatchQueue(label: "com.eerimoq.stream")

private func isMuted(level: Float) -> Bool {
    return level.isNaN
}

private func becameMuted(old: Float, new: Float) -> Bool {
    return !isMuted(level: old) && isMuted(level: new)
}

private func becameUnmuted(old: Float, new: Float) -> Bool {
    return isMuted(level: old) && !isMuted(level: new)
}

final class Media: NSObject {
    private var rtmpConnection = RTMPConnection()
    private var srtConnection = SRTConnection()
    private var rtmpStream: RTMPStream!
    private var srtStream: SRTStream!
    private var srtla: Srtla?
    private var netStream: NetStream!
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    private var srtConnectedObservation: NSKeyValueObservation?
    private var rtmpStreamName = ""
    private var currentAudioLevel: Float = 100.0
    private var srtUrl: String = ""
    private var latency: Int32 = 2000
    private let volumeAudioEffect = VolumeAudioEffect()
    var onSrtConnected: (() -> Void)!
    var onSrtDisconnected: ((_ reason: String) -> Void)!
    var onRtmpConnected: (() -> Void)!
    var onRtmpDisconnected: ((_ message: String) -> Void)!
    var onAudioMuteChange: (() -> Void)!
    var onVideoDeviceInUseByAnotherClient: (() -> Void)!

    private var avgRtt: Double = 0.0
    private var fastRtt: Double = 0.0
    private var curBitrate: Int32 = 250_000
    private var prevBitrate: Int32 = 250_000
    private var maxBitrate: Int32 = 250_000
    private var tempMaxBitrate: Int32 = 250_000
    private var smoothPif: Double = 0
    // private var rttJitter: Int32 = 0
    private var origSize: VideoSize = .init(width: 1280, height: 720)

    private func calcRtts(stats: SRTPerformanceData) {
        if avgRtt < 1 {
            avgRtt = stats.msRTT
        }
        if avgRtt > stats.msRTT {
            avgRtt *= 0.60
            avgRtt += stats.msRTT * 0.40
        } else {
            avgRtt *= 0.99
            if stats.msRTT < 450 {
                avgRtt += stats.msRTT * 0.01
            } else {
                avgRtt += 450 * 0.001
            }
        }
        if fastRtt > stats.msRTT {
            fastRtt *= 0.70
            fastRtt += stats.msRTT * 0.30
        } else {
            fastRtt *= 0.90
            fastRtt += stats.msRTT * 0.10
        }
        if avgRtt > 450 {
            avgRtt = 450
        }
        // rttJitter = Int32(fastRtt - avgRtt)
    }

    private func increaseTempMaxBitrate(
        stats: SRTPerformanceData,
        pif: Double,
        avgRTT _: Double,
        fastRTT _: Double,
        allowedRttJitter: Double,
        allowedPifJitter: Int32
    ) {
        var pifDiffThing = stats.pktFlightSize - Int32(pif)
        if pifDiffThing < 0 {
            pifDiffThing = 0
        }
        if pifDiffThing > 100 {
            pifDiffThing = 100
        }
        // statDeci just used for display on screen
        // statDeci = pifDiffThing
        pifDiffThing = 100 - pifDiffThing
        if pif < 100 && fastRtt <= avgRtt + allowedRttJitter {
            if stats.pktFlightSize - Int32(pif) < allowedPifJitter {
                tempMaxBitrate += (100_000 * pifDiffThing) / 100
                if tempMaxBitrate > maxBitrate {
                    tempMaxBitrate = maxBitrate
                }
            }
        }
    }

    private func calcSmoothedPif(_ stats: SRTPerformanceData) {
        // increase slowly
        if stats.pktFlightSize > Int32(smoothPif) {
            smoothPif *= 0.98
            smoothPif += Double(stats.pktFlightSize) * 0.02
        } else {
            // decrease fast because we really want to be closer to the ideal pif
            smoothPif *= 0.90
            smoothPif += Double(stats.pktFlightSize) * 0.1
        }
    }

    private func decreaseMaxRateIfPifIsHigh(factor: Double, pifMax: Double) {
        if smoothPif > pifMax {
            tempMaxBitrate = Int32(Double(tempMaxBitrate) * factor)
        }
    }

    private func decreaseMaxRateIfRttIsHigh(factor: Double, rttMax: Double) {
        if avgRtt > rttMax {
            tempMaxBitrate = Int32(Double(tempMaxBitrate) * factor)
        }
    }

    private func decreaseMaxRateIfRttDiffIsHigh(
        _ stats: SRTPerformanceData,
        factor: Double,
        rttSpikeAllowed: Double
    ) {
        if stats.msRTT > avgRtt + rttSpikeAllowed {
            tempMaxBitrate = Int32(Double(tempMaxBitrate) * factor)
        }
    }

    private func calculateCurrentBitrate(_ stats: SRTPerformanceData) {
        var pifDiffThing = stats.pktFlightSize - Int32(smoothPif)
        // lazy decrease
        if pifDiffThing > 50 {
            tempMaxBitrate = Int32(Double(tempMaxBitrate) * 0.95)
        }
        if pifDiffThing <= 10 {
            pifDiffThing = 0
        }
        if pifDiffThing < 0 {
            pifDiffThing = 0
        }
        if pifDiffThing > 100 {
            pifDiffThing = 100
        }
        // harder decrease
        if pifDiffThing == 100 {
            tempMaxBitrate -= 500_000
        }
        pifDiffThing = 100 - pifDiffThing
        if tempMaxBitrate < 250_000 {
            tempMaxBitrate = 250_000
        }
        curBitrate = tempMaxBitrate * pifDiffThing
        curBitrate /= 100
        if curBitrate < 50000 {
            curBitrate = 50000
        }
        // pif running away do a quick lower of bitrate temporarily
        if stats.pktFlightSize - Int32(smoothPif) > 200 {
            curBitrate = 50000
        }
    }

    private func adjustVideoQualityIfNeededToActuallyDropBitrateLow(
        _ stats: SRTPerformanceData
    ) {
        if curBitrate < 250_000 &&
            (stats.msRTT > 450 || stats.msRTT > avgRtt * 3 || smoothPif > 200)
        {
            if netStream.videoSettings.videoSize.width != 16 {
                setVideoSizeTemp(size: .init(width: 16, height: 9))
                // setMute(on: true)
            }
        } else if netStream.videoSettings.videoSize.width != origSize.width {
            setVideoSizeTemp(size: origSize)
            // setMute(on: false)
        }
    }

    // NB:To be called every 200ms when live
    // Tested to 15000 sane bitrate, 2000ms latency, rtt generally under 100
    // Assuming rtt is generally < 100 under normal conditions means avg PIF < 100 up
    // to 15000 bitrate
    // rtt > 450 is unacceptable, 4 x 450 = 1800 just under 2000 ms for resend
    // latency
    // avg PIF can spike up to 200 but generally should be < 100
    // actual bitrate will bounce around quite a bit but should be moderately
    // invisible to viewer, the tempmax is the real calculated bitrate but conditions
    // fluctuate so much in IRL that we kind of bounce from 0 to tempmax this gives us
    // a higher overall bitrate and stops us from dropping the bitrate very low and
    // then taking forever to go back up
    func adaptBitrate(stats: SRTPerformanceData) {
        calcSmoothedPif(stats)
        calcRtts(stats: stats)
        increaseTempMaxBitrate(
            stats: stats,
            pif: smoothPif,
            avgRTT: avgRtt,
            fastRTT: fastRtt,
            allowedRttJitter: 15,
            allowedPifJitter: 10
        )
        // slow decreases if needed
        decreaseMaxRateIfPifIsHigh(factor: 0.9, pifMax: 100)
        decreaseMaxRateIfRttIsHigh(factor: 0.9, rttMax: 250)
        decreaseMaxRateIfRttDiffIsHigh(stats, factor: 0.9, rttSpikeAllowed: 50)
        calculateCurrentBitrate(stats)
        adjustVideoQualityIfNeededToActuallyDropBitrateLow(stats)
        if prevBitrate != curBitrate {
            srtlaSetVideoStreamBitrate(bitrate: UInt32(curBitrate))
        }
        prevBitrate = curBitrate
    }

    func logStatistics() {
        srtla?.logStatistics()
    }

    func srtlaConnectionStatistics() -> String? {
        return srtla?.connectionStatistics() ?? nil
    }

    func setNetStream(proto: SettingsStreamProtocol) {
        srtStopStream()
        rtmpStopStream()
        switch proto {
        case .rtmp:
            rtmpStream = RTMPStream(connection: rtmpConnection)
            netStream = rtmpStream
        case .srt:
            srtStream = SRTStream(srtConnection)
            netStream = srtStream
        }
        netStream.delegate = self
        netStream.videoOrientation = .landscapeRight
        attachAudio(device: AVCaptureDevice.default(for: .audio))
    }

    func getAudioLevel() -> Float {
        return currentAudioLevel
    }

    func srtStartStream(
        isSrtla: Bool,
        url: String,
        reconnectTime: Double,
        targetBitrate: UInt32,
        adaptiveBitrate: Bool,
        latency: Int32,
        mpegtsPacketsPerPacket: Int
    ) {
        srtUrl = url
        self.latency = latency
        srtTotalByteCount = 0
        srtPreviousTotalByteCount = 0
        srtla?.stop()
        srtla = Srtla(
            delegate: self,
            passThrough: !isSrtla,
            targetBitrate: targetBitrate,
            adaptiveBitrate: adaptiveBitrate,
            mpegtsPacketsPerPacket: mpegtsPacketsPerPacket
        )
        srtla!.start(uri: url, timeout: reconnectTime + 1)
    }

    func srtStopStream() {
        srtConnection.close()
        srtla?.stop()
        srtla = nil
        srtConnectedObservation = nil
    }

    func getSrtStats() -> [String] {
        let stats = srtConnection.performanceData
        // adaptBitrate(stats: stats)
        return [
            "pktRetransTotal: \(stats.pktRetransTotal)",
            "pktRecvNAKTotal: \(stats.pktRecvNAKTotal)",
            "pktSndDropTotal: \(stats.pktSndDropTotal)",
            "msRTT: \(stats.msRTT)",
            "pktFlightSize: \(stats.pktFlightSize)",
            "pktSndBuf: \(stats.pktSndBuf)",
        ]
    }

    func updateSrtSpeed() {
        srtTotalByteCount = srtla?.getTotalByteCount() ?? 0
        srtSpeed = max(srtTotalByteCount - srtPreviousTotalByteCount, 0)
        srtPreviousTotalByteCount = srtTotalByteCount
    }

    func streamSpeed() -> Int64 {
        if netStream === rtmpStream {
            return Int64(8 * rtmpStream.info.currentBytesPerSecond)
        } else {
            return 8 * srtSpeed
        }
    }

    func streamTotal() -> Int64 {
        if netStream === rtmpStream {
            return rtmpStream.info.byteCount.value
        } else {
            return srtTotalByteCount
        }
    }

    func setupSrtConnectionStateListener() {
        srtConnectedObservation = srtConnection.observe(\.connected, options: [
            .new,
            .old,
        ]) { [weak self] _, connected in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                if connected.newValue! {
                    self.onSrtConnected()
                } else {
                    self.onSrtDisconnected("SRT disconnected")
                }
            }
        }
    }

    func makeLocalhostSrtUrl(url: String, port: UInt16, latency: Int32) -> URL? {
        guard let url = URL(string: url) else {
            return nil
        }
        guard let localUrl = URL(string: "srt://localhost:\(port)") else {
            return nil
        }
        var urlComponents = URLComponents(url: localUrl, resolvingAgainstBaseURL: false)!
        urlComponents.query = url.query
        var queryItems: [URLQueryItem] = urlComponents.queryItems ?? []
        if !queryItems.contains(where: { parameter in
            parameter.name == "latency"
        }) {
            queryItems.append(URLQueryItem(name: "latency", value: String(latency)))
        }
        urlComponents.queryItems = queryItems
        return urlComponents.url
    }

    func rtmpStartStream(url: String) {
        rtmpStreamName = makeRtmpStreamName(url: url)
        rtmpConnection.addEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpConnection.connect(makeRtmpUri(url: url))
    }

    func rtmpStopStream() {
        rtmpConnection.removeEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpStream?.close()
        rtmpConnection.close()
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject,
              let code: String = data["code"] as? String
        else {
            return
        }
        DispatchQueue.main.async {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                self.rtmpStream.publish(self.rtmpStreamName)
                self.onRtmpConnected()
            case RTMPConnection.Code.connectFailed.rawValue,
                 RTMPConnection.Code.connectClosed.rawValue:
                self.onRtmpDisconnected("\(code)")
            default:
                break
            }
        }
    }

    func setTorch(on: Bool) {
        netStream.torch = on
    }

    func setMute(on: Bool) {
        netStream.hasAudio = !on
    }

    func registerEffect(_ effect: VideoEffect) {
        if !netStream.registerVideoEffect(effect) {
            logger.info("Failed to register video effect")
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        _ = netStream.unregisterVideoEffect(effect)
    }

    func registerAudioEffect(_ effect: AudioEffect) {
        if !netStream.registerAudioEffect(effect) {
            logger.info("Failed to register video effect")
        }
    }

    func unregisterAudioEffect(_ effect: AudioEffect) {
        _ = netStream.unregisterAudioEffect(effect)
    }

    func setVideoSessionPreset(preset: AVCaptureSession.Preset) {
        netStream.sessionPreset = preset
    }

    func setVideoSize(size: VideoSize) {
        netStream.videoSettings.videoSize = size
        origSize = size
    }

    func setVideoSizeTemp(size: VideoSize) {
        netStream.videoSettings.videoSize = size
    }

    func getVideoSize() -> VideoSize {
        return netStream.videoSettings.videoSize
    }

    func setStreamFPS(fps: Int) {
        netStream.frameRate = Double(fps)
    }

    func setVideoStreamBitrate(bitrate: UInt32) {
        if let srtla {
            srtla.setTargetBitrate(value: bitrate)
        } else {
            netStream.videoSettings.bitRate = bitrate
        }
    }

    func setAdaptiveBitrate(enabled: Bool) {
        if let srtla {
            srtla.setAdaptiveBitrate(enabled: enabled)
        }
    }

    func setVideoProfile(profile: CFString) {
        netStream.videoSettings.profileLevel = profile as String
    }

    func setCameraZoomLevel(level: Double, ramp: Bool) -> Double? {
        guard let device = netStream.videoCapture(for: 0)?.device else {
            logger.warning("Device not ready to zoom")
            return nil
        }
        let level = level.clamped(to: 1.0 ... device.activeFormat.videoMaxZoomFactor)
        do {
            try device.lockForConfiguration()
            if ramp {
                device.ramp(toVideoZoomFactor: level, withRate: 5.0)
            } else {
                device.videoZoomFactor = level
            }
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.warning("While locking device for ramp: \(error)")
        }
        return level
    }

    func attachCamera(
        device: AVCaptureDevice?,
        videoStabilizationMode: AVCaptureVideoStabilizationMode,
        onSuccess: (() -> Void)? = nil
    ) {
        netStream.videoCapture(for: 0)?
            .preferredVideoStabilizationMode = videoStabilizationMode
        netStream.attachCamera(device, onError: { error in
            logger.error("stream: Attach camera error: \(error)")
        }, onSuccess: {
            DispatchQueue.main.async {
                onSuccess?()
            }
        })
        /* let front = AVCaptureDevice.default(.builtInWideAngleCamera,
                                             for: .video,
                                             position: .front)
         netStream.attachMultiCamera(front) { error in
             print("error: \(error)")
         } */
    }

    func attachAudio(device: AVCaptureDevice?) {
        netStream?.attachAudio(device) { error in
            logger.error("stream: Attach audio error: \(error)")
        }
    }

    func getNetStream() -> NetStream {
        return netStream
    }
}

extension Media: NetStreamDelegate {
    private func kind(_ netStream: NetStream) -> String {
        if (netStream as? RTMPStream) != nil {
            return "RTMP"
        } else if (netStream as? SRTStream) != nil {
            return "SRT"
        } else {
            return "Unknown"
        }
    }

    func stream(
        _: NetStream,
        didOutput _: AVAudioBuffer,
        presentationTimeStamp _: CMTime
    ) {
        // logger.debug("stream: Playback an audio packet incoming.")
    }

    func stream(_: NetStream, didOutput _: CMSampleBuffer) {
        // logger.debug("stream: Playback a video packet incoming.")
    }

    func stream(
        _ netStream: NetStream,
        sessionWasInterrupted _: AVCaptureSession,
        reason: AVCaptureSession.InterruptionReason?
    ) {
        if let reason {
            logger
                .info(
                    "stream: \(kind(netStream)): Session was interrupted with reason: \(reason.toString())"
                )
            if reason == .videoDeviceInUseByAnotherClient {
                onVideoDeviceInUseByAnotherClient()
            }
        } else {
            logger
                .info(
                    "stream: \(kind(netStream)): Session was interrupted without reason"
                )
        }
    }

    func stream(_ netStream: NetStream, sessionInterruptionEnded _: AVCaptureSession) {
        logger.info("stream: \(kind(netStream)): Session interrupted ended.")
    }

    func stream(_ netStream: NetStream, videoCodecErrorOccurred error: VideoCodec.Error) {
        logger.error("stream: \(kind(netStream)): Video codec error: \(error)")
    }

    func stream(_ netStream: NetStream,
                audioCodecErrorOccurred error: HaishinKit.AudioCodec.Error)
    {
        logger.error("stream: \(kind(netStream)): Audio codec error: \(error)")
    }

    func streamWillDropFrame(_: NetStream) -> Bool {
        return false
    }

    func streamDidOpen(_: NetStream) {}

    func stream(_: NetStream, audioLevel: Float) {
        DispatchQueue.main.async {
            if becameMuted(old: self.currentAudioLevel, new: audioLevel) || becameUnmuted(
                old: self.currentAudioLevel,
                new: audioLevel
            ) {
                self.currentAudioLevel = audioLevel
                self.onAudioMuteChange()
            } else {
                self.currentAudioLevel = audioLevel
            }
        }
    }
}

extension Media: SrtlaDelegate {
    func srtlaReady(port: UInt16) {
        DispatchQueue.main.async {
            self.setupSrtConnectionStateListener()
            mediaDispatchQueue.async {
                do {
                    try self.srtConnection.open(self.makeLocalhostSrtUrl(
                        url: self.srtUrl,
                        port: port,
                        latency: self.latency
                    ))
                    self.srtStream?.publish()
                } catch {
                    DispatchQueue.main.async {
                        self.onSrtDisconnected("SRT connect failed with \(error)")
                    }
                }
            }
        }
    }

    func srtlaError(message: String) {
        DispatchQueue.main.async {
            logger.info("stream: SRT error: \(message)")
            self.onSrtDisconnected("SRT error: \(message)")
        }
    }

    func srtlaSetVideoStreamBitrate(bitrate: UInt32) {
        DispatchQueue.main.async {
            self.netStream.videoSettings.bitRate = bitrate
        }
    }
}
