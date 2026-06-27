@preconcurrency import AVFoundation

extension AVAudioPCMBuffer {
    final func makeSampleBuffer(_ presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        guard frameLength > 0 else {
            return nil
        }
        // Get the raw PCM bytes from the first audio buffer in the list.
        let abl = audioBufferList.pointee
        guard abl.mNumberBuffers >= 1 else {
            return nil
        }
        let buf = abl.mBuffers
        guard let srcData = buf.mData, buf.mDataByteSize > 0 else {
            return nil
        }
        let dataSize = Int(buf.mDataByteSize)
        // Create a CMBlockBuffer with a copy of the PCM data.
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: dataSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let blockBuffer else {
            return nil
        }
        status = CMBlockBufferReplaceDataBytes(
            with: srcData,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: dataSize
        )
        guard status == noErr else {
            return nil
        }
        // Build the CMSampleBuffer with CMSampleBufferCreate (for uncompressed PCM).
        var sampleBuffer: CMSampleBuffer?
        let sampleCount = Int(frameLength)
        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        var sampleSize = bytesPerFrame
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(format.sampleRate)),
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format.formatDescription,
            sampleCount: sampleCount,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else {
            return nil
        }
        return sampleBuffer
    }
}
