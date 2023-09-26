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
    var rtmpStream: RTMPStream!
    var srtStream: SRTStream!
    var srtla: Srtla?
    var netStream: NetStream!

    func logStatistics() {
        srtla?.logStatistics()
    }

    func getBestSrtlaConnectionType() -> String? {
        srtla?.findBestConnectionType() ?? nil
    }

    func srtStartStream(
        isSrtla: Bool,
        delegate: SrtlaDelegate,
        url: String?,
        reconnectTime: Double
    ) {
        srtla?.stop()
        srtla = Srtla(delegate: delegate, passThrough: !isSrtla)
        srtla!.start(uri: url!, timeout: reconnectTime + 1)
    }

    func srtStopStream() {
        srtConnection.close()
        srtla?.stop()
        srtla = nil
    }
}
