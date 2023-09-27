import AlertToast
import AVFoundation
import Collections
import Combine
import Foundation
import HaishinKit
import Network
import SRTHaishinKit
import SwiftUI
import VideoToolbox

let streamDispatchQueue = DispatchQueue(label: "com.eerimoq.stream")

func isMuted(level: Float) -> Bool {
    return level.isNaN
}

func becameMuted(old: Float, new: Float) -> Bool {
    return !isMuted(level: old) && isMuted(level: new)
}

func becameUnmuted(old: Float, new: Float) -> Bool {
    return isMuted(level: old) && !isMuted(level: new)
}

final class MediaStream: NSObject {
    private var rtmpConnection = RTMPConnection()
    private var srtConnection = SRTConnection()
    private var rtmpStream: RTMPStream!
    private var srtStream: SRTStream!
    private var srtla: Srtla?
    var netStream: NetStream!
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    private var srtConnectedObservation: NSKeyValueObservation?
    var onSrtConnected: (() -> Void)!
    var onSrtDisconnected: (() -> Void)!
    var onRtmpConnected: (() -> Void)!
    var onRtmpDisconnected: ((_ message: String) -> Void)!
    var onAudioMuteChange: (() -> Void)!
    private var rtmpStreamName = ""
    private var currentAudioLevel: Float = 100.0

    func logStatistics() {
        srtla?.logStatistics()
    }

    func getBestSrtlaConnectionType() -> String? {
        srtla?.findBestConnectionType() ?? nil
    }

    func setNetStream(proto: SettingsStreamProtocol) {
        switch proto {
        case .rtmp:
            srtStream = nil
            rtmpStream = RTMPStream(connection: rtmpConnection)
            netStream = rtmpStream
        case .srt:
            rtmpStream = nil
            srtStream = SRTStream(srtConnection)
            netStream = srtStream
        }
        netStream.delegate = self
    }

    func getAudioLevel() -> Float {
        return currentAudioLevel
    }

    func srtConnect(url: String, port: UInt16) throws {
        try srtConnection.open(makeLocalhostSrtUrl(url: url, port: port))
        srtStream?.publish()
    }

    func srtStartStream(
        isSrtla: Bool,
        delegate: SrtlaDelegate,
        url: String?,
        reconnectTime: Double
    ) {
        srtTotalByteCount = 0
        srtPreviousTotalByteCount = 0
        srtla?.stop()
        srtla = Srtla(delegate: delegate, passThrough: !isSrtla)
        srtla!.start(uri: url!, timeout: reconnectTime + 1)
    }

    func srtStopStream() {
        srtConnection.close()
        srtla?.stop()
        srtla = nil
        srtConnectedObservation = nil
    }

    func getSrtlaTotalByteCount() -> Int64 {
        return srtla?.getTotalByteCount() ?? 0
    }

    func updateSrtSpeed() {
        srtTotalByteCount = getSrtlaTotalByteCount()
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
                    self.onSrtDisconnected()
                }
            }
        }
    }

    func makeLocalhostSrtUrl(url: String, port: UInt16) -> URL? {
        guard let url = URL(string: url) else {
            return nil
        }
        guard let localUrl = URL(string: "srt://localhost:\(port)") else {
            return nil
        }
        var urlComponents = URLComponents(url: localUrl, resolvingAgainstBaseURL: false)!
        urlComponents.query = url.query
        return urlComponents.url
    }

    func rtmpConnect(url: String) {
        rtmpStreamName = makeRtmpStreamName(url: url)
        rtmpConnection.addEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpConnection.connect(makeRtmpUri(url: url))
    }

    func rtmpDisconnect() {
        rtmpConnection.removeEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
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
}

extension MediaStream: NetStreamDelegate {
    func stream(
        _: NetStream,
        didOutput _: AVAudioBuffer,
        presentationTimeStamp _: CMTime
    ) {
        logger.debug("stream: Playback an audio packet incoming.")
    }

    func stream(_: NetStream, didOutput _: CMSampleBuffer) {
        logger.debug("stream: Playback a video packet incoming.")
    }

    func stream(
        _: NetStream,
        sessionWasInterrupted _: AVCaptureSession,
        reason: AVCaptureSession.InterruptionReason?
    ) {
        if let reason {
            logger
                .info("stream: Session was interrupted with reason: \(reason.toString())")
        } else {
            logger.info("stream: Session was interrupted without reason")
        }
    }

    func stream(_: NetStream, sessionInterruptionEnded _: AVCaptureSession) {
        logger.info("stream: Session interrupted ended.")
    }

    func stream(_: NetStream, videoCodecErrorOccurred error: VideoCodec.Error) {
        logger.error("stream: Video codec error: \(error)")
    }

    func stream(_: NetStream,
                audioCodecErrorOccurred error: HaishinKit.AudioCodec.Error)
    {
        logger.error("stream: Audio codec error: \(error)")
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
