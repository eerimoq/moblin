import AVFoundation
import VideoToolbox

var numberOfFailedEncodings = 0

protocol VideoEncoderDelegate: AnyObject {
    func videoEncoderOutputFormat(_ encoder: VideoEncoder, _ formatDescription: CMFormatDescription)
    func videoEncoderOutputSampleBuffer(_ encoder: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _ decodeTimeStampOffset: CMTime)
}

protocol VideoEncoderControlDelegate: AnyObject {
    func videoEncoderControlResolutionChanged(_ encoder: VideoEncoder, resolution: CGSize)
}

class VideoEncoder {
    var settings: Atomic<VideoEncoderSettings> = .init(.init()) {
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
    private var formatDescription: CMFormatDescription?

    weak var delegate: (any VideoEncoderDelegate)?
    weak var controlDelegate: (any VideoEncoderControlDelegate)?
    private var session: VTCompressionSession? {
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

    func startRunning(formatDescription: CMFormatDescription? = nil) {
        lockQueue.async {
            self.isRunning = true
            self.invalidateSession = true
            self.currentBitrate = 0
            self.formatDescription = formatDescription
            numberOfFailedEncodings = 0
            logger.info("video-encoder: Starting with codec \(self.settings.value.format)")
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

    func encodeImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        guard isRunning else {
            return
        }
        let settings = self.settings.value
        let newBitrateVideoSize = updateAdaptiveResolution(settings: settings)
        if newBitrateVideoSize != oldBitrateVideoSize {
            session = makeSession(settings: settings, videoSize: newBitrateVideoSize)
            oldBitrateVideoSize = newBitrateVideoSize
            let resolution = CGSize(width: Double(newBitrateVideoSize.width),
                                    height: Double(newBitrateVideoSize.height))
            controlDelegate?.videoEncoderControlResolutionChanged(self, resolution: resolution)
        }
        if invalidateSession {
            session = makeSession(settings: settings)
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
                    logger.info("""
                    video-encoder: Failed to encode frame status \(status) an got \
                    buffer \(sampleBuffer != nil)
                    """)
                    numberOfFailedEncodings += 1
                    return
                }
                self.setFormatDescription(formatDescription: sampleBuffer.formatDescription)
                self.delegate?.videoEncoderOutputSampleBuffer(self,
                                                              sampleBuffer,
                                                              self.makeDecodeTimeStampOffset(settings))
            }
        }
        if err == kVTInvalidSessionErr {
            logger.info("video-encoder: Encode failed. Resetting session.")
            invalidateSession = true
            currentBitrate = 0
        }
    }

    private func makeDecodeTimeStampOffset(_ settings: VideoEncoderSettings) -> CMTime {
        if settings.allowFrameReordering {
            return CMTime(seconds: 0.15)
        } else {
            return .zero
        }
    }

    private func setFormatDescription(formatDescription: CMFormatDescription?) {
        guard !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: self.formatDescription) else {
            return
        }
        self.formatDescription = formatDescription
        guard let formatDescription else {
            return
        }
        delegate?.videoEncoderOutputFormat(self, formatDescription)
    }

    private func updateBitrate(settings: VideoEncoderSettings) {
        guard currentBitrate != settings.bitRate else {
            return
        }
        currentBitrate = settings.bitRate
        let bitRate = currentBitrate
        let option = VTSessionProperty(key: .averageBitRate, value: NSNumber(value: bitRate))
        if let status = session?.setProperty(option), status != noErr {
            logger.info("video-encoder: Failed to set option \(status) \(option)")
        }
        let optionLimit = VTSessionProperty(key: .dataRateLimits, value: createDataRateLimits(bitRate: bitRate))
        if let status = session?.setProperty(optionLimit), status != noErr {
            logger.info("video-encoder: Failed to set option \(status) \(optionLimit)")
        }
    }

    private func getVideoSize(settings: VideoEncoderSettings) -> CMVideoDimensions? {
        if settings.bitRate < 100_000 {
            return settings.videoSize.convertTo(dimension: 160)
        } else if settings.bitRate < 250_000 {
            return settings.videoSize.convertTo(dimension: 360)
        } else if settings.bitRate < 500_000 {
            return settings.videoSize.convertTo(dimension: 480)
        } else if settings.bitRate < 750_000 {
            return settings.videoSize.convertTo(dimension: 720)
        } else if settings.bitRate < 1_500_000 {
            return settings.videoSize.convertTo(dimension: 1080)
        } else {
            return settings.videoSize
        }
    }

    private func updateAdaptiveResolution(settings: VideoEncoderSettings) -> CMVideoDimensions {
        var videoSize: CMVideoDimensions?
        if settings.adaptiveResolution {
            videoSize = getVideoSize(settings: settings)
        } else {
            videoSize = settings.videoSize
        }
        guard let videoSize, videoSize.height <= settings.videoSize.height else {
            return settings.videoSize
        }
        return videoSize
    }

    private func makeSession(settings: VideoEncoderSettings,
                             videoSize: CMVideoDimensions? = nil) -> VTCompressionSession?
    {
        var session: VTCompressionSession?
        let attributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferWidthKey: NSNumber(value: settings.videoSize.width),
            kCVPixelBufferHeightKey: NSNumber(value: settings.videoSize.height),
        ]
        var status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: videoSize?.width ?? settings.videoSize.width,
            height: videoSize?.height ?? settings.videoSize.height,
            codecType: settings.format.codecType,
            encoderSpecification: nil,
            imageBufferAttributes: attributes as CFDictionary?,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else {
            logger.info("video-encoder: Failed to create session with status \(status)")
            return nil
        }
        status = session.setProperties(settings.properties())
        guard status == noErr else {
            logger.info("video-encoder: Failed to set options with status \(status)")
            return nil
        }
        status = session.prepareToEncodeFrames()
        guard status == noErr else {
            logger.info("video-encoder: Failed to prepare with status \(status)")
            return nil
        }
        return session
    }
}
