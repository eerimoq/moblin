import AVFoundation

extension AVAudioPCMBuffer {
    final func makeSampleBuffer(presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        _ = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: nil,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format.formatDescription,
            sampleCount: Int(frameLength),
            presentationTimeStamp: presentationTimeStamp,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer else {
            return nil
        }
        _ = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: audioBufferList
        )
        return sampleBuffer
    }
}
