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
    var expectedFrameRate = Mixer.defaultFrameRate
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

    private var invalidateSession = true

    func appendImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        guard isRunning.value else {
            return
        }
        if invalidateSession {
            session = makeVideoCompressionSession(self)
        }
        _ = session?.encodeFrame(
            imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration
        ) { [unowned self] status, _, sampleBuffer in
            guard let sampleBuffer, status == noErr else {
                logger.info("Failed to encode frame status \(status) an got buffer \(sampleBuffer != nil)")
                numberOfFailedEncodings += 1
                return
            }
            formatDescription = sampleBuffer.formatDescription
            delegate?.videoCodecOutputSampleBuffer(self, sampleBuffer)
        }
    }

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
        _ = session?
            .decodeFrame(sampleBuffer) { [
                unowned self
            ] status, _, imageBuffer, presentationTimeStamp, duration in
                guard let imageBuffer, status == noErr else {
                    logger.info("Failed to decode frame status \(status)")
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
    }

    @objc
    private func applicationWillEnterForeground(_: Notification) {
        invalidateSession = true
    }

    @objc
    private func didAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo: [AnyHashable: Any] = notification.userInfo,
            let value: NSNumber = userInfo[AVAudioSessionInterruptionTypeKey] as? NSNumber,
            let type = AVAudioSession.InterruptionType(rawValue: value.uintValue)
        else {
            return
        }
        switch type {
        case .ended:
            invalidateSession = true
        default:
            break
        }
    }

    func startRunning() {
        lockQueue.async {
            self.isRunning.mutate { $0 = true }
            numberOfFailedEncodings = 0
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.didAudioSessionInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.session = nil
            self.invalidateSession = true
            self.needsSync.mutate { $0 = true }
            self.formatDescription = nil
            NotificationCenter.default.removeObserver(
                self,
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            self.isRunning.mutate { $0 = false }
        }
    }
}

func makeVideoCompressionSession(_ videoCodec: VideoCodec) -> (any VTSessionConvertible)? {
    var session: VTCompressionSession?
    for attribute in videoCodec.attributes ?? [:] {
        logger.debug("video codec attribute: \(attribute.key) \(attribute.value)")
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
        logger.info("Failed to create status \(status)")
        return nil
    }
    status = session.setOptions(videoCodec.settings.options(videoCodec))
    guard status == noErr else {
        logger.info("Failed to prepare status \(status)")
        return nil
    }
    status = session.prepareToEncodeFrames()
    guard status == noErr else {
        logger.info("Failed to prepare status \(status)")
        return nil
    }
    return session
}

func makeVideoDecompressionSession(_ videoCodec: VideoCodec) -> (any VTSessionConvertible)? {
    guard let formatDescription = videoCodec.formatDescription else {
        logger.info("Failed to create status \(kVTParameterErr)")
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
        logger.info("Failed to create status \(status)")
        return nil
    }
    return session
}
