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
    private static let defaultAttributes: [NSString: AnyObject]? = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
        kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
    ]

    var settings: Atomic<VideoCodecSettings> = .init(.init()) {
        didSet {
            lockQueue.async {
                if self.settings.value.shouldInvalidateSession(oldValue.value) {
                    self.invalidateSession = true
                    self.currentBitrate = 0
                }
            }
        }
    }

    private var isRunning = false
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
        let settings = self.settings.value
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
    private var oldBitrateVideoSize = CMVideoDimensions(width: 0, height: 0)

    init(lockQueue: DispatchQueue) {
        self.lockQueue = lockQueue
    }

    private func updateBitrate(settings: VideoCodecSettings) {
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

    private func getLandscapeVideoSize(settings: VideoCodecSettings) -> CMVideoDimensions {
        if settings.bitRate < 100_000 {
            return .init(width: 284, height: 160)
        } else if settings.bitRate < 250_000 {
            return .init(width: 640, height: 360)
        } else if settings.bitRate < 500_000 {
            return .init(width: 854, height: 480)
        } else if settings.bitRate < 750_000 {
            return .init(width: 1280, height: 720)
        } else {
            return settings.videoSize
        }
    }

    private func getPortraitVideoSize(settings: VideoCodecSettings) -> CMVideoDimensions {
        if settings.bitRate < 100_000 {
            return .init(width: 160, height: 284)
        } else if settings.bitRate < 250_000 {
            return .init(width: 360, height: 640)
        } else if settings.bitRate < 500_000 {
            return .init(width: 480, height: 854)
        } else if settings.bitRate < 750_000 {
            return .init(width: 720, height: 1280)
        } else {
            return settings.videoSize
        }
    }

    private func updateAdaptiveResolution(settings: VideoCodecSettings) -> CMVideoDimensions {
        var videoSize: CMVideoDimensions
        if settings.adaptiveResolution {
            if settings.videoSize.width > settings.videoSize.height {
                videoSize = getLandscapeVideoSize(settings: settings)
            } else {
                videoSize = getPortraitVideoSize(settings: settings)
            }
        } else {
            videoSize = settings.videoSize
        }
        if videoSize.height > settings.videoSize.height {
            videoSize = settings.videoSize
        }
        return videoSize
    }

    func encodeImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        guard isRunning else {
            return
        }
        let settings = self.settings.value
        let newBitrateVideoSize = updateAdaptiveResolution(settings: settings)
        if newBitrateVideoSize != oldBitrateVideoSize {
            session = makeVideoCompressionSession(self, settings: settings, videoSize: newBitrateVideoSize)
            oldBitrateVideoSize = newBitrateVideoSize
        }
        if invalidateSession {
            session = makeVideoCompressionSession(self, settings: settings)
        }
        updateBitrate(settings: settings)
        let err = session?.encodeFrame(
            imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration
        ) { [weak self] status, _, sampleBuffer in
            guard let self else {
                return
            }
            self.lockQueue.async {
                guard let sampleBuffer, status == noErr else {
                    logger.info("video: Failed to encode frame status \(status) an got buffer \(sampleBuffer != nil)")
                    numberOfFailedEncodings += 1
                    return
                }
                self.formatDescription = sampleBuffer.formatDescription
                self.delegate?.videoCodecOutputSampleBuffer(self, sampleBuffer)
            }
        }
        if err == kVTInvalidSessionErr {
            logger.info("video: Encode failed. Resetting session.")
            invalidateSession = true
            currentBitrate = 0
        }
    }

    func decodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        if invalidateSession {
            session = makeVideoDecompressionSession(self)
        }
        let err = session?
            .decodeFrame(sampleBuffer) { [weak self] status, _, imageBuffer, presentationTimeStamp, duration in
                guard let self else {
                    return
                }
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
                self.lockQueue.async {
                    self.delegate?.videoCodecOutputSampleBuffer(self, sampleBuffer)
                }
            }
        if err == kVTInvalidSessionErr {
            logger.info("video: Decode failed. Resetting session.")
            invalidateSession = true
            currentBitrate = 0
        }
    }

    func startRunning(formatDescription: CMFormatDescription? = nil) {
        lockQueue.async {
            self.isRunning = true
            self.invalidateSession = true
            self.currentBitrate = 0
            self.formatDescription = formatDescription
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

private func makeVideoCompressionSession(_ videoCodec: VideoCodec,
                                         settings: VideoCodecSettings,
                                         videoSize: CMVideoDimensions? = nil) -> (any VTSessionConvertible)?
{
    var session: VTCompressionSession?
    for attribute in videoCodec.attributes ?? [:] {
        logger.debug("video: Codec attribute: \(attribute.key) \(attribute.value)")
    }
    var status = VTCompressionSessionCreate(
        allocator: kCFAllocatorDefault,
        width: videoSize?.width ?? settings.videoSize.width,
        height: videoSize?.height ?? settings.videoSize.height,
        codecType: settings.format.codecType,
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
    status = session.setOptions(settings.options(videoCodec))
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

private func makeVideoDecompressionSession(_ videoCodec: VideoCodec) -> (any VTSessionConvertible)? {
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
