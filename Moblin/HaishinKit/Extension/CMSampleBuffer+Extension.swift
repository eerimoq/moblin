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
            logger.info("Failed to create sample buffer with error \(status)")
            return nil
        }
        return sampleBuffer
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
            let attachments: CFArray = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true),
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

    func getSampleSize(at: Int) -> Int {
        return CMSampleBufferGetSampleSize(self, at: at)
    }

    private func makeSampleBuffer(sampleBuffer: CMSampleBuffer,
                                  timeStamp: CMTime) -> CMSampleBuffer?
    {
        var isKeyFrame = sampleBuffer.isKeyFrame
        guard let sampleBuffer = CMSampleBuffer.create(sampleBuffer.imageBuffer!,
                                                       sampleBuffer.formatDescription!,
                                                       sampleBuffer.duration,
                                                       timeStamp,
                                                       sampleBuffer.decodeTimeStamp)
        else {
            return nil
        }
        sampleBuffer.isKeyFrame = isKeyFrame
        return sampleBuffer
    }

    func replacePresentationTimeStamp(presentationTimeStamp: CMTime,
                                      decodeTimeStamp: CMTime = .invalid) -> CMSampleBuffer?
    {
        if let formatDescription = formatDescription {
            let mediaType = CMFormatDescriptionGetMediaType(formatDescription)
            switch mediaType {
            case kCMMediaType_Audio:
                return replaceAudioPresentationTimeStamp(presentationTimeStamp: presentationTimeStamp)
            case kCMMediaType_Video:
                return replaceVideoPresentationTimeStamp(
                    presentationTimeStamp: presentationTimeStamp,
                    decodeTimeStamp: decodeTimeStamp
                )
            default:
                return nil
            }
        } else {
            return nil
        }
    }

    private func replaceAudioPresentationTimeStamp(presentationTimeStamp: CMTime) -> CMSampleBuffer? {
        var newSampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: decodeTimeStamp
        )

        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &newSampleBuffer
        )
        return newSampleBuffer
    }

    private func replaceVideoPresentationTimeStamp(presentationTimeStamp: CMTime,
                                                   decodeTimeStamp: CMTime) -> CMSampleBuffer?
    {
        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(self),
            presentationTimeStamp: presentationTimeStamp,
            decodeTimeStamp: decodeTimeStamp
        )

        var newSampleBuffer: CMSampleBuffer?

        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: self,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &newSampleBuffer
        )

        guard let newSampleBuffer else {
            return nil
        }
        newSampleBuffer.isKeyFrame = isKeyFrame
        return newSampleBuffer
    }
}
