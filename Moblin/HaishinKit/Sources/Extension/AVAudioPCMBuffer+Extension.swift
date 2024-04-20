import AVFoundation

extension AVAudioPCMBuffer {
    final func makeSampleBuffer(presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        var status: OSStatus = noErr
        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateWithPacketDescriptions(
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
            logger.info("CMAudioSampleBufferCreateWithPacketDescriptions returned error: \(status)")
            return nil
        }
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: audioBufferList
        )
        if status != noErr {
            logger.info("CMSampleBufferSetDataBufferFromAudioBufferList returned error: \(status)")
        }
        return sampleBuffer
    }
}
