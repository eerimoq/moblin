import AVFoundation
import VideoToolbox

protocol VideoDecoderDelegate: AnyObject {
    func videoDecoderOutputSampleBuffer(_ codec: VideoDecoder, _ sampleBuffer: CMSampleBuffer)
}

class VideoDecoder {
    private var isRunning = false
    private let lockQueue: DispatchQueue
    private var formatDescription: CMFormatDescription?
    weak var delegate: (any VideoDecoderDelegate)?
    private var invalidateSession = true
    private var session: (any VTSessionConvertible)? {
        didSet {
            oldValue?.invalidate()
            invalidateSession = false
        }
    }

    init(lockQueue: DispatchQueue) {
        self.lockQueue = lockQueue
    }

    func startRunning(formatDescription: CMFormatDescription? = nil) {
        lockQueue.async {
            self.isRunning = true
            self.invalidateSession = true
            self.formatDescription = formatDescription
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.session = nil
            self.invalidateSession = true
            self.formatDescription = nil
            self.isRunning = false
        }
    }

    func decodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        if invalidateSession {
            session = makeSession()
        }
        let err = session?
            .decodeFrame(sampleBuffer) { [weak self] status, _, imageBuffer, presentationTimeStamp, duration in
                guard let self else {
                    return
                }
                guard let imageBuffer, status == noErr else {
                    logger.info("video-decoder: Failed to decode frame status \(status)")
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
                    self.delegate?.videoDecoderOutputSampleBuffer(self, sampleBuffer)
                }
            }
        if err == kVTInvalidSessionErr {
            logger.info("video-decoder: Decode failed. Resetting session.")
            invalidateSession = true
        }
    }

    private func makeSession() -> (any VTSessionConvertible)? {
        guard let formatDescription else {
            logger.info("video-decoder: Format description missing")
            return nil
        }
        let attributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: pixelFormatType),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
        ]
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
            logger.info("video-decoder: Failed to create session with status \(status)")
            return nil
        }
        return session
    }
}
