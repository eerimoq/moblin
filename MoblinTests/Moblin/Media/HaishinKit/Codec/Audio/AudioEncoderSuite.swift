import AVFoundation
@testable import Moblin
import Testing

private final class AudioEncoderTester: AudioEncoderDelegate {
    var numberOfOutputFormats = 0

    func audioEncoderOutputFormat(_: AVAudioFormat) {
        numberOfOutputFormats += 1
    }

    func audioEncoderOutputBuffer(_: AVAudioCompressedBuffer, _: CMTime) {}
}

struct AudioEncoderSuite {
    @Test
    func sameInputSourceFormatKeepsConverter() {
        let tester = AudioEncoderTester()
        let encoder = createEncoder(tester)
        encoder.setInputSourceFormat(createInputSourceFormat(sampleRate: 48000))
        encoder.setInputSourceFormat(createInputSourceFormat(sampleRate: 48000))
        #expect(tester.numberOfOutputFormats == 1)
    }

    @Test
    func newInputSourceFormatCreatesConverter() {
        let tester = AudioEncoderTester()
        let encoder = createEncoder(tester)
        encoder.setInputSourceFormat(createInputSourceFormat(sampleRate: 48000))
        encoder.setInputSourceFormat(createInputSourceFormat(sampleRate: 44100))
        #expect(tester.numberOfOutputFormats == 2)
    }

    @Test
    func sameInputSourceFormatAfterStopCreatesConverter() {
        let tester = AudioEncoderTester()
        let lockQueue = DispatchQueue(label: "audio-encoder-suite")
        let encoder = createEncoder(tester, lockQueue: lockQueue)
        encoder.setInputSourceFormat(createInputSourceFormat(sampleRate: 48000))
        encoder.stopRunning()
        lockQueue.sync {}
        encoder.setInputSourceFormat(createInputSourceFormat(sampleRate: 48000))
        #expect(tester.numberOfOutputFormats == 2)
    }
}

private func createEncoder(
    _ delegate: AudioEncoderTester,
    lockQueue: DispatchQueue = DispatchQueue(label: "audio-encoder-suite")
) -> AudioEncoder {
    let encoder = AudioEncoder(lockQueue: lockQueue)
    encoder.delegate = delegate
    return encoder
}

private func createInputSourceFormat(sampleRate: Double) -> AudioStreamBasicDescription {
    AudioStreamBasicDescription(
        mSampleRate: sampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 2,
        mFramesPerPacket: 1,
        mBytesPerFrame: 2,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 16,
        mReserved: 0
    )
}
