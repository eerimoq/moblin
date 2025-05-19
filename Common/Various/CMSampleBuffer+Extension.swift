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
        return dataBuffer.makeSampleBuffer(presentationTimeStamp: presentationTimeStamp)
    }

    var isSync: Bool {
        get {
            !(getAttachmentValue(for: kCMSampleAttachmentKey_NotSync) ?? false)
        }
        set {
            setAttachmentValue(for: kCMSampleAttachmentKey_NotSync, value: !newValue)
        }
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

    @inline(__always)
    private func getAttachmentValue(for key: CFString) -> Bool? {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(self,
                                                                      createIfNecessary: false) as? [
                [CFString: Any]
            ],
            let value = attachments.first?[key] as? Bool
        else {
            return nil
        }
        return value
    }

    func setAttachmentDisplayImmediately() {
        setAttachmentValue(for: kCMSampleAttachmentKey_DisplayImmediately, value: true)
    }

    @inline(__always)
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
