import AVFoundation
import CoreMedia

extension CMSampleBuffer {
    static func create(
        _ imageBuffer: CVImageBuffer,
        _ formatDescription: CMVideoFormatDescription,
        _ duration: CMTime,
        _ presentationTimeStamp: CMTime,
        _ decodeTimeStamp: CMTime
    ) -> CMSampleBuffer? {
        var sampleTiming = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: decodeTimeStamp
        )
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescription: formatDescription,
            sampleTiming: &sampleTiming,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr else {
            return nil
        }
        return sampleBuffer
    }

    static func createSilent(_ format: AVAudioFormat,
                             _ presentationTimeStamp: CMTime,
                             _ samplesPerBuffer: UInt32) -> CMSampleBuffer?
    {
        guard let dataBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: samplesPerBuffer) else {
            return nil
        }
        guard let data = dataBuffer.int16ChannelData else {
            return nil
        }
        for i in 0 ..< Int(samplesPerBuffer) {
            data.pointee[i] = 0
        }
        dataBuffer.frameLength = samplesPerBuffer
        return dataBuffer.makeSampleBuffer(presentationTimeStamp)
    }

    func setIsSync(_ value: Bool) {
        setAttachmentValue(for: kCMSampleAttachmentKey_NotSync, value: !value)
    }

    func getIsSync() -> Bool {
        return !(getAttachmentValue(for: kCMSampleAttachmentKey_NotSync) ?? false)
    }

    func muted(_ muted: Bool) -> CMSampleBuffer? {
        guard muted else {
            return self
        }
        guard let dataBuffer else {
            return nil
        }
        let status = CMBlockBufferFillDataBytes(
            with: 0,
            blockBuffer: dataBuffer,
            offsetIntoDestination: 0,
            dataLength: dataBuffer.dataLength
        )
        guard status == noErr else {
            return nil
        }
        return self
    }

    func withGain(_ gain: Float) -> CMSampleBuffer? {
        guard gain != 1.0 else {
            return self
        }
        guard let dataBuffer else {
            return nil
        }
        guard let audioStreamBasicDescription = formatDescription?.audioStreamBasicDescription else {
            return nil
        }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        guard status == noErr, let dataPointer else {
            return nil
        }
        let isFloat = audioStreamBasicDescription.mFormatFlags & kAudioFormatFlagIsFloat != 0
        if isFloat, audioStreamBasicDescription.mBitsPerChannel == 32 {
            let count = length / MemoryLayout<Float>.size
            dataPointer.withMemoryRebound(to: Float.self, capacity: count) { samples in
                for i in 0 ..< count {
                    samples[i] *= gain
                }
            }
        } else if audioStreamBasicDescription.mBitsPerChannel == 16 {
            let gain = Int32(gain * 256)
            let count = length / MemoryLayout<Int16>.size
            dataPointer.withMemoryRebound(to: Int16.self, capacity: count) { samples in
                for i in 0 ..< count {
                    samples[i] = Int16(clamping: (Int32(samples[i]) * gain) >> 8)
                }
            }
        }
        return self
    }

    func audioLevel() -> Float {
        guard let dataBuffer = dataBuffer else {
            return .infinity
        }
        guard let audioStreamBasicDescription = formatDescription?.audioStreamBasicDescription
        else {
            return .infinity
        }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )
        guard status == noErr, let dataPointer else {
            return .infinity
        }
        let isFloat = audioStreamBasicDescription.mFormatFlags & kAudioFormatFlagIsFloat != 0
        var sumOfSquares: Float = 0.0
        var count = 0
        if isFloat, audioStreamBasicDescription.mBitsPerChannel == 32 {
            count = min(length / MemoryLayout<Float>.size, 256)
            dataPointer.withMemoryRebound(to: Float.self, capacity: count) { samples in
                for index in 0 ..< count {
                    sumOfSquares += samples[index] * samples[index]
                }
            }
        } else if audioStreamBasicDescription.mBitsPerChannel == 16 {
            count = min(length / MemoryLayout<Int16>.size, 256)
            dataPointer.withMemoryRebound(to: Int16.self, capacity: count) { samples in
                for index in 0 ..< count {
                    let normalized = Float(samples[index]) / Float(Int16.max)
                    sumOfSquares += normalized * normalized
                }
            }
        }
        guard count > 0 else {
            return .infinity
        }
        let rms = sqrt(sumOfSquares / Float(count))
        guard rms > 0 else {
            return -160.0
        }
        return 20.0 * log10(rms)
    }

    private func getAttachmentValue(for key: CFString) -> Bool? {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(
                self,
                createIfNecessary: false
            ) as? [[CFString: Any]],
            let value = attachments.first?[key] as? Bool
        else {
            return nil
        }
        return value
    }

    func setAttachmentDisplayImmediately() {
        setAttachmentValue(for: kCMSampleAttachmentKey_DisplayImmediately, value: true)
    }

    private func setAttachmentValue(for key: CFString, value: Bool) {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true),
            CFArrayGetCount(attachments) > 0
        else {
            return
        }
        let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(
            attachment,
            Unmanaged.passUnretained(key).toOpaque(),
            Unmanaged.passUnretained(value ? kCFBooleanTrue : kCFBooleanFalse).toOpaque()
        )
    }

    func replacePresentationTimeStamp(_ presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        var timingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        var newSampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &newSampleBuffer
        )
        return newSampleBuffer
    }

    func deepCopyAudioSampleBuffer() -> CMSampleBuffer? {
        guard let formatDescription, let dataBuffer else {
            return nil
        }
        do {
            let data = try dataBuffer.dataBytes()
            let dataBufferCopy = try data.withUnsafeBytes { buffer -> CMBlockBuffer in
                let blockBuffer = try CMBlockBuffer(length: data.count)
                try blockBuffer.replaceDataBytes(with: buffer)
                return blockBuffer
            }
            return try? CMSampleBuffer(dataBuffer: dataBufferCopy,
                                       formatDescription: formatDescription,
                                       numSamples: numSamples,
                                       presentationTimeStamp: presentationTimeStamp,
                                       packetDescriptions: [])
        } catch {
            return nil
        }
    }
}
