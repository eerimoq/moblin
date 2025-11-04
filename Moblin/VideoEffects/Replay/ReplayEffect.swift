import AVFoundation
import CoreImage
import Vision

private let fadeTransitionLength = 0.5

enum ReplayEffectTransitionMode: Equatable {
    case none
    case fade
    case video(inTransition: URL, outTarnsition: URL)
}

protocol ReplayEffectDelegate: AnyObject {
    func replayEffectStatus(timeLeft: Int)
    func replayEffectCompleted()
}

final class ReplayEffect: VideoEffect {
    private var playbackCompleted = false
    private let speed: Double
    private let reader: ReplayEffectReplayReader
    private var startPresentationTimeStamp: Double?
    private weak var delegate: ReplayEffectDelegate?
    private var lastImageOffset: Double?
    private var latestImage: CIImage?
    private var cancelled = false
    private var cancelledOffset: Double?
    private let transitionMode: ReplayEffectTransitionMode
    private let duration: Double
    private var latestTimeLeft = Int.max

    init(
        video: ReplayBufferFile,
        start: Double,
        stop: Double,
        speed: Double,
        size: CMVideoDimensions,
        transitionMode: ReplayEffectTransitionMode,
        delegate: ReplayEffectDelegate
    ) {
        self.speed = speed
        self.transitionMode = transitionMode
        self.delegate = delegate
        duration = stop - start
        reader = ReplayEffectReplayReader(video: video, start: start, duration: duration, size: size)
    }

    func cancel() {
        processorPipelineQueue.async {
            self.cancelled = true
        }
    }

    override func getName() -> String {
        return "replay"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let presentationTimeStamp = info.presentationTimeStamp.seconds
        if startPresentationTimeStamp == nil {
            startPresentationTimeStamp = presentationTimeStamp
        }
        let offset = info.presentationTimeStamp.seconds - startPresentationTimeStamp!
        if cancelled, cancelledOffset == nil {
            cancelledOffset = offset
        }
        switch transitionMode {
        case .none, .fade:
            return executeNoneAndFade(image: image, offset: offset)
        case .video:
            return executeVideo(image: image, offset: offset)
        }
    }

    override func shouldRemove() -> Bool {
        return playbackCompleted
    }

    private func updateStatus(offset: Double) {
        let timeLeft = max(Int((duration / speed - offset).rounded(.up)), 0)
        if timeLeft != latestTimeLeft {
            latestTimeLeft = timeLeft
            delegate?.replayEffectStatus(timeLeft: timeLeft)
        }
    }
}

extension ReplayEffect {
    private func executeNoneAndFade(image: CIImage, offset: Double) -> CIImage {
        if let cancelledOffset {
            return executeEndNoneAndFade(image, offset - cancelledOffset) ?? image
        } else if let lastImageOffset {
            updateStatus(offset: offset)
            return executeEndNoneAndFade(image, offset - lastImageOffset) ?? image
        } else {
            updateStatus(offset: offset)
            return executeBeginAndMiddleNoneAndFade(image, offset) ?? image
        }
    }

    private func executeBeginAndMiddleNoneAndFade(_ image: CIImage, _ offset: Double) -> CIImage? {
        let replayImage = reader.getImage(offset: offset * speed)
        latestImage = replayImage.image ?? latestImage
        if replayImage.isLast {
            lastImageOffset = offset
        } else if replayImage.image == nil {
            startPresentationTimeStamp = nil
        }
        if case .fade = transitionMode, offset <= fadeTransitionLength {
            return applyFadeTransition(image, replayImage.image, offset)
        } else {
            return replayImage.image ?? latestImage
        }
    }

    private func executeEndNoneAndFade(_ image: CIImage, _ offset: Double) -> CIImage? {
        if case .fade = transitionMode, offset <= fadeTransitionLength {
            return applyFadeTransition(latestImage, image, offset)
        } else {
            playbackCompleted = true
            if !cancelled {
                delegate?.replayEffectCompleted()
            }
            return image
        }
    }

    private func applyFadeTransition(_ input: CIImage?, _ target: CIImage?, _ offset: Double) -> CIImage? {
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = input
        filter.targetImage = target
        filter.time = Float(offset / fadeTransitionLength)
        return filter.outputImage
    }
}

extension ReplayEffect {
    private func executeVideo(image: CIImage, offset _: Double) -> CIImage {
        return image
    }
}
