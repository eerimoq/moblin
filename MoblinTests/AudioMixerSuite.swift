import AVFoundation
@testable import Moblin
import Testing

private let processDelayMs = 100

struct AudioMixerSuite {
    @Test func oneMonoInputMonoOutput() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId = UUID()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        #expect(mixer.numberOfInputs() == 0)
        mixer.add(inputId: inputId, format: format)
        #expect(mixer.numberOfInputs() == 1)
        let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        inputBuffer.frameLength = 1024
        inputBuffer.floatChannelData?.pointee[0] = 1
        inputBuffer.floatChannelData?.pointee[1] = 10
        inputBuffer.floatChannelData?.pointee[1023] = 100
        mixer.append(inputId: inputId, sampleTime: 0, buffer: inputBuffer)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 1)
        #expect(outputBuffer?.frameLength == 1024)
        #expect(outputBuffer?.floatChannelData?.pointee[0] == 1 / sqrt(2))
        #expect(outputBuffer?.floatChannelData?.pointee[1] == 10 / sqrt(2))
        #expect(outputBuffer?.floatChannelData?.pointee[500] == 0)
        #expect(outputBuffer?.floatChannelData?.pointee[1022] == 0)
        #expect(outputBuffer?.floatChannelData?.pointee[1023] == 100 / sqrt(2))
        mixer.remove(inputId: inputId)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test func oneMonoInput24khzMonoOutput48khz() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId = UUID()
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        mixer.add(inputId: inputId, format: format)
        let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        inputBuffer.frameLength = 512
        inputBuffer.floatChannelData?.pointee[0] = 10
        inputBuffer.floatChannelData?.pointee[1] = 20
        inputBuffer.floatChannelData?.pointee[2] = 30
        inputBuffer.floatChannelData?.pointee[3] = 40
        inputBuffer.floatChannelData?.pointee[4] = 50
        inputBuffer.floatChannelData?.pointee[508] = 100
        inputBuffer.floatChannelData?.pointee[509] = 100
        inputBuffer.floatChannelData?.pointee[510] = 100
        inputBuffer.floatChannelData?.pointee[511] = 100
        mixer.append(inputId: inputId, sampleTime: 0, buffer: inputBuffer)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 1)
        #expect(outputBuffer?.frameLength == 1024)
        #expect((5.94 ... 5.95).contains(outputBuffer!.floatChannelData!.pointee[0]))
        #expect((10.53 ... 10.54).contains(outputBuffer!.floatChannelData!.pointee[1]))
        #expect((15.58 ... 15.59).contains(outputBuffer!.floatChannelData!.pointee[2]))
        #expect((18.55 ... 18.56).contains(outputBuffer!.floatChannelData!.pointee[3]))
        #expect((19.49 ... 19.50).contains(outputBuffer!.floatChannelData!.pointee[4]))
        #expect((22.56 ... 22.57).contains(outputBuffer!.floatChannelData!.pointee[5]))
        #expect((30.2 ... 30.21).contains(outputBuffer!.floatChannelData!.pointee[6]))
        #expect((36.89 ... 36.90).contains(outputBuffer!.floatChannelData!.pointee[7]))
        #expect((33.33 ... 33.34).contains(outputBuffer!.floatChannelData!.pointee[8]))
        #expect((18.28 ... 18.29).contains(outputBuffer!.floatChannelData!.pointee[9]))
        #expect((1.98 ... 1.99).contains(outputBuffer!.floatChannelData!.pointee[10]))
        #expect((-4.71 ... -4.7).contains(outputBuffer!.floatChannelData!.pointee[11]))
        #expect((-1.84 ... -1.83).contains(outputBuffer!.floatChannelData!.pointee[12]))
        #expect((2.07 ... 2.08).contains(outputBuffer!.floatChannelData!.pointee[13]))
        #expect((1.57 ... 1.58).contains(outputBuffer!.floatChannelData!.pointee[14]))
        #expect((70.31 ... 70.32).contains(outputBuffer!.floatChannelData!.pointee[1022]))
        #expect((37.66 ... 37.67).contains(outputBuffer!.floatChannelData!.pointee[1023]))
        mixer.remove(inputId: inputId)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test func oneMonoInputMonoOutputThreeBuffers() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId = UUID()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        #expect(mixer.numberOfInputs() == 0)
        mixer.add(inputId: inputId, format: format)
        #expect(mixer.numberOfInputs() == 1)
        let inputBuffer1 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        inputBuffer1.frameLength = 1024
        inputBuffer1.floatChannelData?.pointee[0] = 1
        inputBuffer1.floatChannelData?.pointee[1] = 10
        inputBuffer1.floatChannelData?.pointee[1023] = 100
        mixer.append(inputId: inputId, sampleTime: 0, buffer: inputBuffer1)
        let inputBuffer2 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        inputBuffer2.frameLength = 1024
        inputBuffer2.floatChannelData?.pointee[0] = 10
        inputBuffer2.floatChannelData?.pointee[1] = 2
        inputBuffer2.floatChannelData?.pointee[1023] = 1
        mixer.append(inputId: inputId, sampleTime: 1024, buffer: inputBuffer2)
        let inputBuffer3 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        inputBuffer3.frameLength = 1024
        inputBuffer3.floatChannelData?.pointee[0] = 100
        inputBuffer3.floatChannelData?.pointee[1] = 2
        inputBuffer3.floatChannelData?.pointee[1023] = 10000
        mixer.append(inputId: inputId, sampleTime: 2048 + 1024, buffer: inputBuffer3)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer1 = mixer.process()
        #expect(outputBuffer1?.format.sampleRate == 48000)
        #expect(outputBuffer1?.format.channelCount == 1)
        #expect(outputBuffer1?.frameLength == 1024)
        #expect(outputBuffer1?.floatChannelData?.pointee[0] == 1 / sqrt(2))
        #expect(outputBuffer1?.floatChannelData?.pointee[1] == 10 / sqrt(2))
        #expect(outputBuffer1?.floatChannelData?.pointee[1023] == 100 / sqrt(2))
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer2 = mixer.process()
        #expect(outputBuffer2?.frameLength == 1024)
        #expect(outputBuffer2?.floatChannelData?.pointee[0] == 10 / sqrt(2))
        #expect(outputBuffer2?.floatChannelData?.pointee[1] == 2 / sqrt(2))
        #expect(outputBuffer2?.floatChannelData?.pointee[1023] == 1 / sqrt(2))
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer3 = mixer.process()
        #expect(outputBuffer3?.frameLength == 1024)
        #expect(outputBuffer3?.floatChannelData?.pointee[0] == 0)
        #expect(outputBuffer3?.floatChannelData?.pointee[1] == 0)
        #expect(outputBuffer3?.floatChannelData?.pointee[1023] == 0)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer4 = mixer.process()
        #expect(outputBuffer4?.frameLength == 1024)
        #expect(outputBuffer4?.floatChannelData?.pointee[0] == 100 / sqrt(2))
        #expect(outputBuffer4?.floatChannelData?.pointee[1] == 2 / sqrt(2))
        #expect(outputBuffer4?.floatChannelData?.pointee[1023] == 10000 / sqrt(2))
        mixer.remove(inputId: inputId)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test func twoMonoInputsMonoOutput() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 1, outputSamplesPerBuffer: 1024)
        let inputId1 = UUID()
        let inputId2 = UUID()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        mixer.add(inputId: inputId1, format: format)
        mixer.add(inputId: inputId2, format: format)
        #expect(mixer.numberOfInputs() == 2)
        let inputBuffer1 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        inputBuffer1.frameLength = 1024
        inputBuffer1.floatChannelData?.pointee[0] = 1
        inputBuffer1.floatChannelData?.pointee[1] = 10
        inputBuffer1.floatChannelData?.pointee[1023] = 100
        mixer.append(inputId: inputId1, sampleTime: 0, buffer: inputBuffer1)
        let inputBuffer2 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        inputBuffer2.frameLength = 1024
        inputBuffer2.floatChannelData?.pointee[0] = 1
        inputBuffer2.floatChannelData?.pointee[1] = 10
        inputBuffer2.floatChannelData?.pointee[2] = 1
        inputBuffer2.floatChannelData?.pointee[3] = 10
        inputBuffer2.floatChannelData?.pointee[1022] = 100
        inputBuffer2.floatChannelData?.pointee[1023] = 300
        mixer.append(inputId: inputId2, sampleTime: 0, buffer: inputBuffer2)
        try? await sleep(milliSeconds: processDelayMs)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 1)
        #expect(outputBuffer?.frameLength == 1024)
        #expect(outputBuffer?.floatChannelData?.pointee[0] == 2 / sqrt(2))
        #expect(outputBuffer?.floatChannelData?.pointee[1] == 20 / sqrt(2))
        #expect(outputBuffer?.floatChannelData?.pointee[2] == 1 / sqrt(2))
        #expect(outputBuffer?.floatChannelData?.pointee[3] == 10 / sqrt(2))
        #expect(outputBuffer?.floatChannelData?.pointee[500] == 0)
        #expect(outputBuffer?.floatChannelData?.pointee[1022] == 100 / sqrt(2))
        #expect(outputBuffer?.floatChannelData?.pointee[1023] == 400 / sqrt(2))
        mixer.remove(inputId: inputId1)
        #expect(mixer.numberOfInputs() == 1)
        mixer.remove(inputId: inputId2)
        #expect(mixer.numberOfInputs() == 0)
    }

    @Test func noInputStereoOutput() async throws {
        let mixer = AudioMixer(outputSampleRate: 48000, outputChannels: 2, outputSamplesPerBuffer: 1024)
        let outputBuffer = mixer.process()
        #expect(outputBuffer?.format.sampleRate == 48000)
        #expect(outputBuffer?.format.channelCount == 2)
        #expect(outputBuffer?.frameLength == 1024)
        #expect(outputBuffer?.stride == 1)
        #expect(outputBuffer?.floatChannelData?.pointee[0] == 0)
        #expect(outputBuffer?.floatChannelData?.pointee[1023] == 0)
        #expect(outputBuffer?.floatChannelData?.pointee[1024] == 0)
        #expect(outputBuffer?.floatChannelData?.pointee[2047] == 0)
    }
}
