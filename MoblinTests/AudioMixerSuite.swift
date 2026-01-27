import AVFoundation
@testable import Moblin
import Testing

private let processDelayMs = 100

struct AudioMixerSuite {
    @Test
    func oneMonoInputMonoOutput() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId = UUID()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        #expect(mixer.numberOfInputs() == 0)
        mixer.add(inputId: inputId, format: format)
        #expect(mixer.numberOfInputs() == 1)
        let inputBuffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
        inputBuffer.frameLength = 1024
        var samples = try #require(inputBuffer.floatChannelData?.pointee)
        samples[0] = 1
        samples[1] = 10
        samples[1023] = 100
        mixer.append(inputId: inputId, buffer: inputBuffer)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 1)
        #expect(outputBuffer?.frameLength == 1024)
        samples = try #require(outputBuffer?.floatChannelData?.pointee)
        #expect(samples[0] == 1 / sqrt(2))
        #expect(samples[1] == 10 / sqrt(2))
        #expect(samples[500] == 0)
        #expect(samples[1022] == 0)
        #expect(samples[1023] == 100 / sqrt(2))
        mixer.remove(inputId: inputId)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test
    func oneMonoInput24khzMonoOutput48khz() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId = UUID()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1))
        mixer.add(inputId: inputId, format: format)
        let inputBuffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
        inputBuffer.frameLength = 512
        var samples = try #require(inputBuffer.floatChannelData?.pointee)
        samples[0] = 10
        samples[1] = 20
        samples[2] = 30
        samples[3] = 40
        samples[4] = 50
        samples[508] = 100
        samples[509] = 100
        samples[510] = 100
        samples[511] = 100
        mixer.append(inputId: inputId, buffer: inputBuffer)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 1)
        #expect(outputBuffer?.frameLength == 1024)
        samples = try #require(outputBuffer?.floatChannelData?.pointee)
        #expect(isEqual(samples[0], 5.94, epsilon: 0.01))
        #expect(isEqual(samples[1], 10.53, epsilon: 0.01))
        #expect(isEqual(samples[2], 15.58, epsilon: 0.01))
        #expect(isEqual(samples[3], 18.55, epsilon: 0.01))
        #expect(isEqual(samples[4], 19.49, epsilon: 0.01))
        #expect(isEqual(samples[5], 22.56, epsilon: 0.01))
        #expect(isEqual(samples[6], 30.2, epsilon: 0.01))
        #expect(isEqual(samples[7], 36.89, epsilon: 0.01))
        #expect(isEqual(samples[8], 33.33, epsilon: 0.01))
        #expect(isEqual(samples[9], 18.28, epsilon: 0.01))
        #expect(isEqual(samples[10], 1.98, epsilon: 0.01))
        #expect(isEqual(samples[11], -4.71, epsilon: 0.01))
        #expect(isEqual(samples[12], -1.84, epsilon: 0.01))
        #expect(isEqual(samples[13], 2.07, epsilon: 0.01))
        #expect(isEqual(samples[14], 1.57, epsilon: 0.01))
        #expect(isEqual(samples[1022], 70.31, epsilon: 0.01))
        #expect(isEqual(samples[1023], 37.66, epsilon: 0.01))
        mixer.remove(inputId: inputId)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test
    func oneMonoInputMonoOutputThreeBuffers() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId = UUID()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        #expect(mixer.numberOfInputs() == 0)
        mixer.add(inputId: inputId, format: format)
        #expect(mixer.numberOfInputs() == 1)
        let inputBuffer1 = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
        inputBuffer1.frameLength = 1024
        var samples = try #require(inputBuffer1.floatChannelData?.pointee)
        samples[0] = 1
        samples[1] = 10
        samples[1023] = 100
        mixer.append(inputId: inputId, buffer: inputBuffer1)
        let inputBuffer2 = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
        inputBuffer2.frameLength = 1024
        samples = try #require(inputBuffer2.floatChannelData?.pointee)
        samples[0] = 10
        samples[1] = 2
        samples[1023] = 1
        mixer.append(inputId: inputId, buffer: inputBuffer2)
        let inputBuffer3 = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
        inputBuffer3.frameLength = 1024
        samples = try #require(inputBuffer3.floatChannelData?.pointee)
        samples[0] = 100
        samples[1] = 2
        samples[1023] = 10000
        mixer.append(inputId: inputId, buffer: inputBuffer3)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer1 = mixer.process()
        #expect(outputBuffer1?.format.sampleRate == 48000)
        #expect(outputBuffer1?.format.channelCount == 1)
        #expect(outputBuffer1?.frameLength == 1024)
        samples = try #require(outputBuffer1?.floatChannelData?.pointee)
        #expect(samples[0] == 1 / sqrt(2))
        #expect(samples[1] == 10 / sqrt(2))
        #expect(samples[1023] == 100 / sqrt(2))
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer2 = mixer.process()
        #expect(outputBuffer2?.frameLength == 1024)
        samples = try #require(outputBuffer2?.floatChannelData?.pointee)
        #expect(samples[0] == 10 / sqrt(2))
        #expect(samples[1] == 2 / sqrt(2))
        #expect(samples[1023] == 1 / sqrt(2))
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer3 = mixer.process()
        #expect(outputBuffer3?.frameLength == 1024)
        samples = try #require(outputBuffer3?.floatChannelData?.pointee)
        #expect(samples[0] == 100 / sqrt(2))
        #expect(samples[1] == 2 / sqrt(2))
        #expect(samples[1023] == 10000 / sqrt(2))
        mixer.remove(inputId: inputId)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test
    func twoMonoInputsMonoOutput() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId1 = UUID()
        let inputId2 = UUID()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        mixer.add(inputId: inputId1, format: format)
        mixer.add(inputId: inputId2, format: format)
        #expect(mixer.numberOfInputs() == 2)
        let inputBuffer1 = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
        inputBuffer1.frameLength = 1024
        var samples = try #require(inputBuffer1.floatChannelData?.pointee)
        samples[0] = 1
        samples[1] = 10
        samples[1023] = 100
        mixer.append(inputId: inputId1, buffer: inputBuffer1)
        let inputBuffer2 = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
        inputBuffer2.frameLength = 1024
        samples = try #require(inputBuffer2.floatChannelData?.pointee)
        samples[0] = 1
        samples[1] = 10
        samples[2] = 1
        samples[3] = 10
        samples[1022] = 100
        samples[1023] = 300
        mixer.append(inputId: inputId2, buffer: inputBuffer2)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 1)
        #expect(outputBuffer?.frameLength == 1024)
        samples = try #require(outputBuffer?.floatChannelData?.pointee)
        #expect(samples[0] == 2 / sqrt(2))
        #expect(samples[1] == 20 / sqrt(2))
        #expect(samples[2] == 1 / sqrt(2))
        #expect(samples[3] == 10 / sqrt(2))
        #expect(samples[500] == 0)
        #expect(samples[1022] == 100 / sqrt(2))
        #expect(samples[1023] == 400 / sqrt(2))
        mixer.remove(inputId: inputId1)
        #expect(mixer.numberOfInputs() == 1)
        mixer.remove(inputId: inputId2)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test
    func noInputStereoOutput() throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 2, outputSamplesPerBuffer: 1024)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 2)
        #expect(outputBuffer?.frameLength == 1024)
        #expect(outputBuffer?.stride == 1)
        let samples = try #require(outputBuffer?.floatChannelData?.pointee)
        #expect(samples[0] == 0)
        #expect(samples[1023] == 0)
        #expect(samples[1024] == 0)
        #expect(samples[2047] == 0)
    }
}
