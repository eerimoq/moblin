@testable import Moblin
import Testing

struct RtmpStreamInfoSuite {
    @Test
    func initialState() {
        let info = RtmpStreamInfo()
        #expect(info.bytesSent.value == 0)
        #expect(info.currentBytesPerSecond.value == 0)
        #expect(info.stats.value.rttMs == 0)
        #expect(info.stats.value.packetsInFlight == 0)
    }

    @Test
    func clearResetsState() {
        let info = RtmpStreamInfo()
        info.bytesSent.mutate { $0 = 5000 }
        info.onTimeout()
        info.onWritten(sequence: 1400)
        info.clear()
        #expect(info.bytesSent.value == 0)
        #expect(info.currentBytesPerSecond.value == 0)
        #expect(info.stats.value.rttMs == 0)
        #expect(info.stats.value.packetsInFlight == 0)
    }

    @Test
    func onTimeoutCalculatesBytesPerSecond() {
        let info = RtmpStreamInfo()
        info.bytesSent.mutate { $0 = 1000 }
        info.onTimeout()
        #expect(info.currentBytesPerSecond.value == 300)
    }

    @Test
    func onTimeoutExponentialSmoothing() {
        let info = RtmpStreamInfo()
        info.bytesSent.mutate { $0 = 1000 }
        info.onTimeout()
        #expect(info.currentBytesPerSecond.value == 300)
        info.bytesSent.mutate { $0 = 2000 }
        info.onTimeout()
        #expect(info.currentBytesPerSecond.value == 510)
        info.bytesSent.mutate { $0 = 2000 }
        info.onTimeout()
        #expect(info.currentBytesPerSecond.value == 357)
    }

    @Test
    func onTimeoutNoNewBytes() {
        let info = RtmpStreamInfo()
        info.onTimeout()
        #expect(info.currentBytesPerSecond.value == 0)
        info.onTimeout()
        #expect(info.currentBytesPerSecond.value == 0)
    }

    @Test
    func onWrittenUpdatesPacketsInFlight() {
        let info = RtmpStreamInfo()
        info.onWritten(sequence: 1400)
        #expect(info.stats.value.packetsInFlight == 1)
        info.onWritten(sequence: 4200)
        #expect(info.stats.value.packetsInFlight == 3)
    }

    @Test
    func onAckReducesPacketsInFlight() {
        let info = RtmpStreamInfo()
        info.onWritten(sequence: 1400)
        #expect(info.stats.value.packetsInFlight == 1)
        info.onWritten(sequence: 2800)
        #expect(info.stats.value.packetsInFlight == 2)
        info.onWritten(sequence: 4200)
        #expect(info.stats.value.packetsInFlight == 3)
        info.onAck(sequence: 2800)
        #expect(info.stats.value.packetsInFlight == 1)
        info.onAck(sequence: 4201)
        #expect(info.stats.value.packetsInFlight == 0)
    }

    @Test
    func onAckUpdatesRtt() async throws {
        let info = RtmpStreamInfo()
        info.onWritten(sequence: 1400)
        try await sleep(milliSeconds: 200)
        info.onAck(sequence: 1401)
        #expect(info.stats.value.rttMs > 0)
    }

    @Test
    func onAckSequenceRolloverAtInt32Max() {
        let info = RtmpStreamInfo()
        info.onWritten(sequence: Int64(Int32.max) - 500)
        info.onWritten(sequence: Int64(Int32.max) + 5000)
        info.onAck(sequence: UInt32(Int32.max) - 600)
        info.onAck(sequence: 1000)
        #expect(info.stats.value.packetsInFlight == 2)
    }

    @Test
    func onAckSequenceRolloverAtUInt32Max() {
        let info = RtmpStreamInfo()
        let aboveInt32Max = UInt32(Int32.max) + 1000
        info.onWritten(sequence: Int64(aboveInt32Max) - 500)
        info.onWritten(sequence: Int64(UInt32.max) + 5000)
        info.onAck(sequence: aboveInt32Max - 600)
        info.onAck(sequence: 1000)
        #expect(info.stats.value.packetsInFlight == 2)
    }

    @Test
    func packetsInFlightNeverNegative() {
        let info = RtmpStreamInfo()
        info.onAck(sequence: 5000)
        info.onWritten(sequence: 1400)
        #expect(info.stats.value.packetsInFlight == 0)
    }

    @Test
    func multipleOnWrittenAccumulatesTimings() {
        let info = RtmpStreamInfo()
        for i in 1 ... 10 {
            info.onWritten(sequence: Int64(i) * 1400)
        }
        #expect(info.stats.value.packetsInFlight == 10)
        info.onAck(sequence: 7000)
        #expect(info.stats.value.packetsInFlight == 5)
    }
}
