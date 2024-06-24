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

    static let defaultAttributes: [NSString: AnyObject]? = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
        kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
    ]

    var settings: VideoCodecSettings = .init() {
        didSet {
            lockQueue.async {
                if self.settings.shouldInvalidateSession(oldValue) {
                    self.invalidateSession = true
                    self.currentBitrate = 0
                }
            }
        }
    }

    private var isRunning: Bool = false
    private let lockQueue: DispatchQueue
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

    private var invalidateSession = true
    private var currentBitrate: UInt32 = 0

    private func updateBitrate() {
        guard currentBitrate != settings.bitRate else {
            return
        }
        currentBitrate = settings.bitRate
        let bitRate = currentBitrate
        let option = VTSessionOption(key: .averageBitRate, value: NSNumber(value: bitRate))
        if let status = session?.setOption(option), status != noErr {
            logger.info("video: Failed to set option \(status) \(option)")
        }
        let optionLimit = VTSessionOption(key: .dataRateLimits, value: createDataRateLimits(bitRate: bitRate))
        if let status = session?.setOption(optionLimit), status != noErr {
            logger.info("video: Failed to set option \(status) \(optionLimit)")
        }
    }

    func appendImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        guard isRunning else {
            return
        }
        if invalidateSession {
            session = makeVideoCompressionSession(self)
        }
        updateBitrate()
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
            logger.info("video: Encode failed. Resetting session.")
            invalidateSession = true
            currentBitrate = 0
        }
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        if invalidateSession {
            session = makeVideoDecompressionSession(self)
        }
        let err = session?.decodeFrame(sampleBuffer) { [
            unowned self
        ] status, _, imageBuffer, presentationTimeStamp, duration in
            guard let imageBuffer, status == noErr else {
                logger.info("video: Failed to decode frame status \(status)")
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
            delegate?.videoCodecOutputSampleBuffer(self, sampleBuffer)
        }
        if err == kVTInvalidSessionErr {
            logger.info("video: Decode failed. Resetting session.")
            invalidateSession = true
            currentBitrate = 0
        }
    }

    func startRunning() {
        lockQueue.async {
            self.isRunning = true
            numberOfFailedEncodings = 0
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.session = nil
            self.invalidateSession = true
            self.currentBitrate = 0
            self.formatDescription = nil
            self.isRunning = false
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
