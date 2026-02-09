import AVFoundation
import Foundation
import Testing

@testable import RTCHaishinKit

@Suite struct RTPJitterBufferTests {
    final class Result: RTPJitterBufferDelegate {
        var count = 0

        func jitterBuffer(_ buffer: RTPJitterBuffer<RTPJitterBufferTests.Result>, sequenced: RTPPacket) {
            count += 1
        }
    }

    @Test func lostPacket() throws {
        let result = Result()
        let buffer = RTPJitterBuffer<Result>()
        buffer.delegate = result
        var packets: [RTPPacket] = []
        for i in 0...100 {
            packets.append(.init(version: 2, padding: false, extension: false, cc: 0, marker: false, payloadType: 0, sequenceNumber: UInt16(i), timestamp: UInt32(960 * (i + 1)), ssrc: 0, payload: Data()))
        }
        packets.remove(at: 30)
        packets.remove(at: 50)
        for packet in packets {
            buffer.append(packet)
        }

        #expect(result.count == 99)
    }
}
