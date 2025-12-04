import Foundation
@testable import Moblin
import Testing

struct WavSuite {
    @Test
    func mono() async throws {
        let samples: [[Int16]] = [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]]
        let wav = createWav(sampleRate: 48000, samples: samples)
        #expect(wav == createMonoWav(samples[0]))
    }

    @Test
    func stereo() async throws {
        let samplesRight: [Int16] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        let samplesLeft: [Int16] = [0, -1, -2, -3, -4, -5, -6, -7, -8, -9]
        let wav = createWav(sampleRate: 48000, samples: [samplesRight, samplesLeft])
        #expect(wav == createStereoWav(samplesRight, samplesLeft))
    }
}

private func createMonoWav(_ samples: [Int16]) -> Data {
    let dataSize = UInt32(samples.count * 2)
    let writer = ByteWriter()
    writer.writeUTF8Bytes("RIFF")
    writer.writeUInt32Le(44 - 8 + dataSize)
    writer.writeUTF8Bytes("WAVE")
    writer.writeUTF8Bytes("fmt ")
    writer.writeUInt32Le(16)
    writer.writeUInt16Le(1) // int16
    writer.writeUInt16Le(1) // Mono
    writer.writeUInt32Le(48000) // sample rate
    writer.writeUInt32Le(0x02EE00) // 192 kbps
    writer.writeUInt16Le(4)
    writer.writeUInt16Le(16)
    writer.writeUTF8Bytes("data")
    writer.writeUInt32Le(dataSize)
    for sample in samples {
        writer.writeUInt16Le(UInt16(bitPattern: sample))
    }
    return writer.data
}

private func createStereoWav(_ samplesRight: [Int16], _ samplesLeft: [Int16]) -> Data {
    #expect(samplesRight.count == samplesLeft.count)
    let dataSize = UInt32(samplesRight.count * 2 * 2)
    let writer = ByteWriter()
    writer.writeUTF8Bytes("RIFF")
    writer.writeUInt32Le(44 - 8 + dataSize)
    writer.writeUTF8Bytes("WAVE")
    writer.writeUTF8Bytes("fmt ")
    writer.writeUInt32Le(16)
    writer.writeUInt16Le(1) // int16
    writer.writeUInt16Le(2) // Stereo
    writer.writeUInt32Le(48000) // sample rate
    writer.writeUInt32Le(0x02EE00) // 192 kbps
    writer.writeUInt16Le(4)
    writer.writeUInt16Le(16)
    writer.writeUTF8Bytes("data")
    writer.writeUInt32Le(dataSize)
    for (sampleRight, sampleLeft) in zip(samplesRight, samplesLeft) {
        writer.writeUInt16Le(UInt16(bitPattern: sampleRight))
        writer.writeUInt16Le(UInt16(bitPattern: sampleLeft))
    }
    return writer.data
}
