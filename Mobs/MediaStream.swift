import AlertToast
import Collections
import Combine
import Foundation
import HaishinKit
import Network
import SRTHaishinKit
import SwiftUI
import VideoToolbox

let streamDispatchQueue = DispatchQueue(label: "com.eerimoq.stream")

final class MediaStream {
    var rtmpConnection = RTMPConnection()
    var srtConnection = SRTConnection()
    private var rtmpStream: RTMPStream!
    private var srtStream: SRTStream!
    private var srtla: Srtla?
    var netStream: NetStream!
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0

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
    }

    func rtmpPublish(url: String) {
        rtmpStream.publish(makeRtmpStreamName(url: url))
    }

    func srtConnect(url: URL?) throws {
        try srtConnection.open(url)
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
}
