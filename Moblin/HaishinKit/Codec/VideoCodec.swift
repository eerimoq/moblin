import AVFoundation
import CoreFoundation
import UIKit
import VideoToolbox

var numberOfFailedEncodings = 0

protocol VideoCodecDelegate: AnyObject {
    func videoCodecOutputFormat(_ codec: VideoCodec, _ formatDescription: CMFormatDescription)
    func videoCodecOutputSampleBuffer(_ codec: VideoCodec, _ sampleBuffer: CMSampleBuffer)
}

class VideoCodec {
    init(lockQueue: DispatchQueue) {
        self.lockQueue = lockQueue
    }

    static var defaultAttributes: [NSString: AnyObject]? = [
        kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
    ]

    var settings: VideoCodecSettings = .init() {
        didSet {
            if settings.shouldInvalidateSession(oldValue) {
                invalidateSession = true
            } else {
                settings.apply(self)
            }
        }
    }

    private(set) var isRunning: Atomic<Bool> = .init(false)
    private let lockQueue: DispatchQueue
    var expectedFrameRate = VideoUnit.defaultFrameRate
    var formatDescription: CMFormatDescription? {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: oldValue) else {
                return
            }
            guard let formatDescription else {
                return
            }
            delegate?.videoCodecOutputFormat(self, formatDescription)
        }
    }

    private var needsSync: Atomic<Bool> = .init(true)
    var attributes: [NSString: AnyObject]? {
        guard VideoCodec.defaultAttributes != nil else {
            return nil
        }
        var attributes: [NSString: AnyObject] = [:]
        for (key, value) in VideoCodec.defaultAttributes ?? [:] {
            attributes[key] = value
        }
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: settings.videoSize.width)
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: settings.videoSize.height)
        return attributes
    }

    weak var delegate: (any VideoCodecDelegate)?
    private(set) var session: (any VTSessionConvertible)? {
        didSet {
            oldValue?.invalidate()
            invalidateSession = false
        }
    }

    var invalidateSession = true

    func appendImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        guard isRunning.value else {
            return
        }
        if invalidateSession {
            session = makeVideoCompressionSession(self)
        }
        let err = session?.encodeFrame(
            imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration
        ) { [unowned self] status, _, sampleBuffer in
            guard let sampleBuffer, status == noErr else {
                logger
                    .info(
                        "video: Failed to encode frame status \(status) an got buffer \(sampleBuffer != nil)"
                    )
                numberOfFailedEncodings += 1
                return
            }
            formatDescription = sampleBuffer.formatDescription
            delegate?.videoCodecOutputSampleBuffer(self, sampleBuffer)
        }
        if err == kVTInvalidSessionErr {
            logger.debug("video: Encode failed. Resetting session.")
            invalidateSession = true
        }
    }

    private var lastSampleBuffer: CMSampleBuffer?

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning.value else {
            return
        }
        if invalidateSession {
            session = makeVideoDecompressionSession(self)
            needsSync.mutate { $0 = true }
        }
        if sampleBuffer.isKeyFrame {
            needsSync.mutate { $0 = false }
        }
        let err = session?.decodeFrame(sampleBuffer) { [
            unowned self
        ] status, _, imageBuffer, presentationTimeStamp, duration in
            guard let imageBuffer, status == noErr else {
                logger.info("video: Failed to decode frame status \(status)")
                guard let lastSampleBuffer else {
                    return
                }
                delegate?.videoCodecOutputSampleBuffer(self, lastSampleBuffer)
                return
            }
            guard let formatDescription = CMVideoFormatDescription.create(imageBuffer: imageBuffer) else {
                return
            }
            guard let sampleBuffer = CMSampleBuffer.create(imageBuffer,
                                                           formatDescription,
                                                           duration,
                                                           presentationTimeStamp,
                                                           sampleBuffer.decodeTimeStamp)
            else {
                return
            }
            lastSampleBuffer = sampleBuffer
            delegate?.videoCodecOutputSampleBuffer(self, sampleBuffer)
        }
        if err == kVTInvalidSessionErr {
            logger.debug("video: Decode failed. Resetting session.")
            invalidateSession = true
        }
    }

    func startRunning() {
        lockQueue.async {
            self.isRunning.mutate { $0 = true }
            numberOfFailedEncodings = 0
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.session = nil
            self.invalidateSession = true
            self.needsSync.mutate { $0 = true }
            self.formatDescription = nil
            self.isRunning.mutate { $0 = false }
        }
    }
}

func makeVideoCompressionSession(_ videoCodec: VideoCodec) -> (any VTSessionConvertible)? {
    var session: VTCompressionSession?
    for attribute in videoCodec.attributes ?? [:] {
        logger.debug("video: Codec attribute: \(attribute.key) \(attribute.value)")
    }
    var status = VTCompressionSessionCreate(
        allocator: kCFAllocatorDefault,
        width: videoCodec.settings.videoSize.width,
        height: videoCodec.settings.videoSize.height,
        codecType: videoCodec.settings.format.codecType,
        encoderSpecification: nil,
        imageBufferAttributes: videoCodec.attributes as CFDictionary?,
        compressedDataAllocator: nil,
        outputCallback: nil,
        refcon: nil,
        compressionSessionOut: &session
    )
    guard status == noErr, let session else {
        logger.info("video: Failed to create status \(status)")
        return nil
    }
    status = session.setOptions(videoCodec.settings.options(videoCodec))
    guard status == noErr else {
        logger.info("video: Failed to prepare status \(status)")
        return nil
    }
    status = session.prepareToEncodeFrames()
    guard status == noErr else {
        logger.info("video: Failed to prepare status \(status)")
        return nil
    }
    return session
}

func makeVideoDecompressionSession(_ videoCodec: VideoCodec) -> (any VTSessionConvertible)? {
    guard let formatDescription = videoCodec.formatDescription else {
        logger.info("video: Failed to create status \(kVTParameterErr)")
        return nil
    }
    var attributes = videoCodec.attributes
    attributes?.removeValue(forKey: kCVPixelBufferWidthKey)
    attributes?.removeValue(forKey: kCVPixelBufferHeightKey)
    var session: VTDecompressionSession?
    let status = VTDecompressionSessionCreate(
        allocator: kCFAllocatorDefault,
        formatDescription: formatDescription,
        decoderSpecification: nil,
        imageBufferAttributes: attributes as CFDictionary?,
        outputCallback: nil,
        decompressionSessionOut: &session
    )
    guard status == noErr else {
        logger.info("video: Failed to create status \(status)")
        return nil
    }
    return session
}
