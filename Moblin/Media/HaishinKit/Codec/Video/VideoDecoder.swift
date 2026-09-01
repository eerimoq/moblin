@preconcurrency import AVFoundation
import VideoToolbox

protocol VideoDecoderDelegate: AnyObject {
    func videoDecoderOutputSampleBuffer(_ codec: VideoDecoder, _ sampleBuffer: CMSampleBuffer)
}

class VideoDecoder: @unchecked Sendable {
    private var isRunning = false
    private let name: String
    private let lockQueue: DispatchQueue
    private let softwareDecoding: Bool
    private var formatDescription: CMFormatDescription?
    weak var delegate: (any VideoDecoderDelegate)?
    private var invalidateSession = true
    private var numberOfFailedFrames = 0
    private var latestFailedFrameStatus: OSStatus = noErr
    private var session: VTDecompressionSession? {
        didSet {
            oldValue?.invalidate()
            invalidateSession = false
        }
    }

    init(name: String, lockQueue: DispatchQueue, softwareDecoding: Bool) {
        self.name = name
        self.lockQueue = lockQueue
        self.softwareDecoding = softwareDecoding
    }

    func startRunning(formatDescription: CMFormatDescription? = nil) {
        isRunning = true
        invalidateSession = true
        numberOfFailedFrames = 0
        self.formatDescription = formatDescription
    }

    func stopRunning() {
        session = nil
        invalidateSession = true
        formatDescription = nil
        isRunning = false
    }

    func decodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        if invalidateSession {
            session = makeSession()
        }
        let err = session?
            .decodeFrame(sampleBuffer) { [
                weak self
            ] status, _, imageBuffer, presentationTimeStamp, duration in
                guard let self else {
                    return
                }
                guard let imageBuffer, status == noErr else {
                    lockQueue.async {
                        self.numberOfFailedFrames += 1
                        self.latestFailedFrameStatus = status
                    }
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
                lockQueue.async {
                    self.logFailedFrames()
                    self.delegate?.videoDecoderOutputSampleBuffer(self, sampleBuffer)
                }
            }
        if err == kVTInvalidSessionErr {
            logger.info("video-decoder: \(name): Decode failed. Resetting session.")
            invalidateSession = true
        }
    }

    private func logFailedFrames() {
        guard numberOfFailedFrames > 0 else {
            return
        }
        logger.info("""
        video-decoder: \(name): Failed to decode \(numberOfFailedFrames) frame(s). \
        Latest status \(latestFailedFrameStatus).
        """)
        numberOfFailedFrames = 0
    }

    private func makeSession() -> VTDecompressionSession? {
        guard let formatDescription else {
            logger.info("video-decoder: \(name): Format description missing")
            return nil
        }
        let attributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
        ]
        var decoderSpecification: [NSString: AnyObject]?
        if #available(iOS 17.0, *), softwareDecoding {
            decoderSpecification = [
                kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder: kCFBooleanFalse,
            ]
        }
        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: decoderSpecification as CFDictionary?,
            imageBufferAttributes: attributes as CFDictionary?,
            outputCallback: nil,
            decompressionSessionOut: &session
        )
        guard status == noErr else {
            logger.info("video-decoder: \(name): Failed to create session with status \(status)")
            return nil
        }
        return session
    }
}
