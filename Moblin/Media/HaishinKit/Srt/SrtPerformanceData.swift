import Foundation
import libsrt

struct SrtPerformanceData {
    static let zero = SrtPerformanceData(
        pktRetransTotal: 0,
        pktRecvNakTotal: 0,
        pktSndDropTotal: 0,
        pktFlightSize: 0,
        msRtt: 0,
        pktSndBuf: 0,
        mbpsSendRate: 0
    )

    var pktRetransTotal: Int32
    var pktRecvNakTotal: Int32
    var pktSndDropTotal: Int32
    var pktFlightSize: Int32
    var msRtt: Double
    var pktSndBuf: Int32
    var mbpsSendRate: Double

    init(mon: CBytePerfMon) {
        pktRetransTotal = mon.pktRetransTotal
        pktRecvNakTotal = mon.pktRecvNAKTotal
        pktSndDropTotal = mon.pktSndDropTotal
        pktFlightSize = mon.pktFlightSize
        msRtt = mon.msRTT
        pktSndBuf = mon.pktSndBuf
        mbpsSendRate = mon.mbpsSendRate
    }

    init(
        pktRetransTotal: Int32,
        pktRecvNakTotal: Int32,
        pktSndDropTotal: Int32,
        pktFlightSize: Int32,
        msRtt: Double,
        pktSndBuf: Int32,
        mbpsSendRate: Double
    ) {
        self.pktRetransTotal = pktRetransTotal
        self.pktRecvNakTotal = pktRecvNakTotal
        self.pktSndDropTotal = pktSndDropTotal
        self.pktFlightSize = pktFlightSize
        self.msRtt = msRtt
        self.pktSndBuf = pktSndBuf
        self.mbpsSendRate = mbpsSendRate
    }
}
