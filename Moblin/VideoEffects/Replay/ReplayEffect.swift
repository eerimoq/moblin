import AVFoundation
import Collections
import CoreImage
import Vision

private let fadeTransitionLength = 0.5
let replayEffectQueue = DispatchQueue(label: "com.eerimoq.replay-effect")

enum ReplayEffectTransitionMode: Equatable {
    case fade
    case stingers(inPath: URL,
                  inTransitionPoint: Double,
                  outPath: URL,
                  outTransitionPoint: Double)
    case none
}

protocol ReplayEffectDelegate: AnyObject {
    func replayEffectStatus(timeLeft: Int)
    func replayEffectCompleted()
    func replayEffectError(message: String)
}

private enum StingersState {
    case setup
    case begin
    case middle
    case end
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
    private var stingersState: StingersState = .setup
    private var stingersInReader: ReplayEffectStingerReader?
    private var stingersOutReader: ReplayEffectStingerReader?
    private var stingersInTransitionPoint: Double = 0
    private var stingersOutTransitionPoint: Double = 0
    private var stingersInTransitionPointPresentationTimeStamp: Double = 0
    private var stingersOutTransitionStartPresentationTimeStamp: Double = 0
    private var stingersOutTransitionPointPresentationTimeStamp: Double = 0

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
        super.init()
        if case let .stingers(inPath, inTransitionPoint, outPath, outTransitionPoint) = transitionMode {
            stingersInReader = ReplayEffectStingerReader(path: inPath, size: size)
            stingersInTransitionPoint = inTransitionPoint
            stingersOutReader = ReplayEffectStingerReader(path: outPath, size: size)
            stingersOutTransitionPoint = outTransitionPoint
        }
        updateStatus(offset: 0)
    }

    func cancel() {
        processorPipelineQueue.async {
            self.cancelled = true
        }
    }

    override func getName() -> String {
        return "Replay"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        switch transitionMode {
        case .none, .fade:
            return executeNoneAndFade(image, info.presentationTimeStamp.seconds)
        case .stingers:
            return executeStingers(image, info.presentationTimeStamp.seconds)
        }
    }

    override func shouldRemove() -> Bool {
        return playbackCompleted
    }

    private func updateStatus(offset: Double) {
        guard !cancelled else {
            return
        }
        let timeLeft = max(Int((duration / speed - offset).rounded(.up)), 0)
        if timeLeft != latestTimeLeft {
            latestTimeLeft = timeLeft
            delegate?.replayEffectStatus(timeLeft: timeLeft)
        }
    }

    private func replayCompleted() {
        playbackCompleted = true
        if !cancelled {
            delegate?.replayEffectCompleted()
        }
    }
}

extension ReplayEffect {
    private func executeNoneAndFade(_ image: CIImage, _ presentationTimeStamp: Double) -> CIImage {
        if startPresentationTimeStamp == nil {
            startPresentationTimeStamp = presentationTimeStamp
        }
        let offset = presentationTimeStamp - startPresentationTimeStamp!
        updateStatus(offset: offset)
        if cancelled {
            if cancelledOffset == nil {
                cancelledOffset = offset
            }
            return executeEndNoneAndFade(image, offset - cancelledOffset!) ?? image
        } else if let lastImageOffset {
            return executeEndNoneAndFade(image, offset - lastImageOffset) ?? image
        } else {
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
            replayCompleted()
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
    private func executeStingers(_ image: CIImage, _ presentationTimeStamp: Double) -> CIImage {
        switch stingersState {
        case .setup:
            return executeStingersSetup(image, presentationTimeStamp)
        case .begin:
            return executeStingersBegin(image, presentationTimeStamp)
        case .middle:
            return executeStingersMiddle(image, presentationTimeStamp)
        case .end:
            return executeStingersEnd(image, presentationTimeStamp)
        }
    }

    private func executeStingersSetup(_ image: CIImage, _ presentationTimeStamp: Double) -> CIImage {
        guard let stingersInReader, let stingersOutReader else {
            return image
        }
        if case .ok = stingersInReader.setupState, case .ok = stingersOutReader.setupState {
            startPresentationTimeStamp = presentationTimeStamp
            stingersInTransitionPointPresentationTimeStamp = presentationTimeStamp
                + stingersInReader.duration * stingersInTransitionPoint
            stingersOutTransitionPointPresentationTimeStamp = stingersInTransitionPointPresentationTimeStamp +
                duration / speed
            stingersOutTransitionStartPresentationTimeStamp = stingersOutTransitionPointPresentationTimeStamp
                - stingersOutReader.duration * stingersOutTransitionPoint
            stingersState = .begin
        } else if case .failed = stingersInReader.setupState {
            reportBadStingerVideo()
            replayCompleted()
        } else if case .failed = stingersOutReader.setupState {
            reportBadStingerVideo()
            replayCompleted()
        }
        return image
    }

    private func executeStingersBegin(_ image: CIImage, _ presentationTimeStamp: Double) -> CIImage {
        updateCancelled(presentationTimeStamp)
        let backgroundImage = getStingersBackgroundImage(image, presentationTimeStamp)
        let offset = presentationTimeStamp - startPresentationTimeStamp!
        if let stingerImage = stingersInReader?.getImage(offset: offset)?.image {
            return stingerImage.composited(over: backgroundImage)
        } else {
            stingersState = .middle
            return backgroundImage
        }
    }

    private func executeStingersMiddle(_ image: CIImage, _ presentationTimeStamp: Double) -> CIImage {
        updateCancelled(presentationTimeStamp)
        if presentationTimeStamp >= stingersOutTransitionStartPresentationTimeStamp {
            stingersState = .end
        }
        return getReplayImage(presentationTimeStamp, image) ?? image
    }

    private func executeStingersEnd(_ image: CIImage, _ presentationTimeStamp: Double) -> CIImage {
        let backgroundImage = getStingersBackgroundImage(image, presentationTimeStamp)
        let offset = presentationTimeStamp - stingersOutTransitionStartPresentationTimeStamp
        if let stingerImage = stingersOutReader?.getImage(offset: offset)?.image {
            return stingerImage.composited(over: backgroundImage)
        } else {
            replayCompleted()
            return backgroundImage
        }
    }

    private func getStingersBackgroundImage(_ image: CIImage, _ presentationTimeStamp: Double) -> CIImage {
        if presentationTimeStamp < stingersInTransitionPointPresentationTimeStamp {
            return image
        } else if presentationTimeStamp > stingersOutTransitionPointPresentationTimeStamp {
            updateStatus(offset: duration / speed)
            return image
        } else {
            return getReplayImage(presentationTimeStamp, image) ?? image
        }
    }

    private func getReplayImage(_ presentationTimeStamp: Double, _: CIImage) -> CIImage? {
        let offset = presentationTimeStamp - stingersInTransitionPointPresentationTimeStamp
        updateStatus(offset: offset)
        return reader.getImage(offset: offset * speed).image
    }

    private func updateCancelled(_ presentationTimeStamp: Double) {
        guard cancelled, let stingersOutReader else {
            return
        }
        stingersState = .end
        stingersOutTransitionStartPresentationTimeStamp = presentationTimeStamp
        stingersOutTransitionPointPresentationTimeStamp = presentationTimeStamp
            + stingersOutReader.duration * stingersOutTransitionPoint
    }

    private func reportBadStingerVideo() {
        delegate?.replayEffectError(message: String(localized: "Bad replay stinger video"))
    }
}
