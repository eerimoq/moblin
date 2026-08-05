import Collections
import CoreImage
import MetalPetal
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

private enum ReplayEffectOutput {
    case background
    case replay(EffectImageCiImage)
    case fadeToReplay(EffectImageCiImage, Double)
    case fadeToBackground(EffectImageCiImage, Double)
    case stinger(EffectImageCiImage, EffectImageCiImage?)
}

final class ReplayEffect: VideoEffect, @unchecked Sendable {
    private var playbackCompleted = false
    private let speed: Double
    private let reader: ReplayEffectReplayReader
    private var startPresentationTimeStamp: Double?
    private weak var delegate: (any ReplayEffectDelegate)?
    private var lastImageOffset: Double?
    private var latestImage: EffectImageCiImage?
    private var cancelled = false
    private var cancelledOffset: Double?
    private let transitionMode: ReplayEffectTransitionMode
    private let duration: Double
    private var layout: SettingsWidgetLayout
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
        layout: SettingsWidgetLayout,
        transitionMode: ReplayEffectTransitionMode,
        delegate: any ReplayEffectDelegate
    ) {
        self.speed = speed
        self.layout = layout
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

    func setLayout(layout: SettingsWidgetLayout) {
        processorPipelineQueue.async {
            self.layout = layout
        }
    }

    func cancel() {
        processorPipelineQueue.async {
            self.cancelled = true
        }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        switch update(info.presentationTimeStamp.seconds) {
        case .background:
            return image
        case let .replay(replayImage):
            return applyLayoutToReplay(replayImage, image)
        case let .fadeToReplay(replayImage, ratio):
            return fade(image, applyLayoutToReplay(replayImage, image), ratio) ?? image
        case let .fadeToBackground(replayImage, ratio):
            return fade(applyLayoutToReplay(replayImage, image), image, ratio) ?? image
        case let .stinger(stingerImage, replayImage):
            let backgroundImage = replayImage.map { applyLayoutToReplay($0, image) } ?? image
            return stingerImage.getCiImage().composited(over: backgroundImage)
        }
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        switch update(info.presentationTimeStamp.seconds) {
        case .background:
            return image
        case let .replay(replayImage):
            return applyLayoutToReplayMetalPetal(replayImage, image)
        case let .fadeToReplay(replayImage, ratio):
            return fadeMetalPetal(image, applyLayoutToReplayMetalPetal(replayImage, image), ratio)
        case let .fadeToBackground(replayImage, ratio):
            return fadeMetalPetal(applyLayoutToReplayMetalPetal(replayImage, image), image, ratio)
        case let .stinger(stingerImage, replayImage):
            let backgroundImage = replayImage.map { applyLayoutToReplayMetalPetal($0, image) } ?? image
            return blendMetalPetal(stingerImage.getMetalPetalImage(), backgroundImage, 1)
        }
    }

    override func shouldRemove() -> Bool {
        playbackCompleted
    }

    private func update(_ presentationTimeStamp: Double) -> ReplayEffectOutput {
        switch transitionMode {
        case .none, .fade:
            updateNoneAndFade(presentationTimeStamp)
        case .stingers:
            updateStingers(presentationTimeStamp)
        }
    }

    private func applyLayoutToReplay(_ replayImage: EffectImageCiImage, _ image: CIImage) -> CIImage {
        replayImage.getCiImage()
            .resizeMirror(layout, image.extent.size, false)
            .move(layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    private func applyLayoutToReplayMetalPetal(_ replayImage: EffectImageCiImage,
                                               _ image: MTIImage) -> MTIImage
    {
        let replayImage = replayImage.getMetalPetalImage()
        return replayImage.resizeMirrorMoveComposited(layout,
                                                      false,
                                                      image,
                                                      .init(contentRegion: replayImage.extent))
    }

    private func fade(_ input: CIImage, _ target: CIImage, _ ratio: Double) -> CIImage? {
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = input
        filter.targetImage = target
        filter.time = Float(ratio)
        return filter.outputImage
    }

    private func fadeMetalPetal(_ input: MTIImage, _ target: MTIImage, _ ratio: Double) -> MTIImage {
        blendMetalPetal(target, input, Float(ratio))
    }

    private func blendMetalPetal(_ image: MTIImage,
                                 _ backgroundImage: MTIImage,
                                 _ intensity: Float) -> MTIImage
    {
        let filter = MTIBlendFilter(blendMode: .normal)
        filter.inputBackgroundImage = backgroundImage
        filter.inputImage = image
        filter.intensity = intensity
        return filter.outputImage ?? backgroundImage
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
    private func updateNoneAndFade(_ presentationTimeStamp: Double) -> ReplayEffectOutput {
        if startPresentationTimeStamp == nil {
            startPresentationTimeStamp = presentationTimeStamp
        }
        let offset = presentationTimeStamp - startPresentationTimeStamp!
        updateStatus(offset: offset)
        if cancelled {
            if cancelledOffset == nil {
                cancelledOffset = offset
            }
            return updateEndNoneAndFade(offset - cancelledOffset!)
        } else if let lastImageOffset {
            return updateEndNoneAndFade(offset - lastImageOffset)
        } else {
            return updateBeginAndMiddleNoneAndFade(offset)
        }
    }

    private func updateBeginAndMiddleNoneAndFade(_ offset: Double) -> ReplayEffectOutput {
        let replayImage = reader.getImage(offset: offset * speed)
        latestImage = replayImage.image ?? latestImage
        if replayImage.isLast {
            lastImageOffset = offset
        } else if replayImage.image == nil {
            startPresentationTimeStamp = nil
        }
        guard let latestImage else {
            return .background
        }
        if case .fade = transitionMode, offset <= fadeTransitionLength {
            return .fadeToReplay(latestImage, offset / fadeTransitionLength)
        } else {
            return .replay(latestImage)
        }
    }

    private func updateEndNoneAndFade(_ offset: Double) -> ReplayEffectOutput {
        if case .fade = transitionMode, offset <= fadeTransitionLength {
            guard let latestImage else {
                return .background
            }
            return .fadeToBackground(latestImage, offset / fadeTransitionLength)
        } else {
            replayCompleted()
            return .background
        }
    }
}

extension ReplayEffect {
    private func updateStingers(_ presentationTimeStamp: Double) -> ReplayEffectOutput {
        switch stingersState {
        case .setup:
            updateStingersSetup(presentationTimeStamp)
        case .begin:
            updateStingersBegin(presentationTimeStamp)
        case .middle:
            updateStingersMiddle(presentationTimeStamp)
        case .end:
            updateStingersEnd(presentationTimeStamp)
        }
    }

    private func updateStingersSetup(_ presentationTimeStamp: Double) -> ReplayEffectOutput {
        guard let stingersInReader, let stingersOutReader else {
            return .background
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
        return .background
    }

    private func updateStingersBegin(_ presentationTimeStamp: Double) -> ReplayEffectOutput {
        updateCancelled(presentationTimeStamp)
        let backgroundImage = getStingersBackgroundImage(presentationTimeStamp)
        let offset = presentationTimeStamp - startPresentationTimeStamp!
        if let stingerImage = stingersInReader?.getImage(offset: offset)?.image {
            return .stinger(stingerImage, backgroundImage)
        } else {
            stingersState = .middle
            return makeBackgroundOutput(backgroundImage)
        }
    }

    private func updateStingersMiddle(_ presentationTimeStamp: Double) -> ReplayEffectOutput {
        updateCancelled(presentationTimeStamp)
        if presentationTimeStamp >= stingersOutTransitionStartPresentationTimeStamp {
            stingersState = .end
        }
        return makeBackgroundOutput(getReplayImage(presentationTimeStamp))
    }

    private func updateStingersEnd(_ presentationTimeStamp: Double) -> ReplayEffectOutput {
        let backgroundImage = getStingersBackgroundImage(presentationTimeStamp)
        let offset = presentationTimeStamp - stingersOutTransitionStartPresentationTimeStamp
        if let stingerImage = stingersOutReader?.getImage(offset: offset)?.image {
            return .stinger(stingerImage, backgroundImage)
        } else {
            replayCompleted()
            return makeBackgroundOutput(backgroundImage)
        }
    }

    private func makeBackgroundOutput(_ replayImage: EffectImageCiImage?) -> ReplayEffectOutput {
        guard let replayImage else {
            return .background
        }
        return .replay(replayImage)
    }

    private func getStingersBackgroundImage(_ presentationTimeStamp: Double) -> EffectImageCiImage? {
        if presentationTimeStamp < stingersInTransitionPointPresentationTimeStamp {
            return nil
        } else if presentationTimeStamp > stingersOutTransitionPointPresentationTimeStamp {
            updateStatus(offset: duration / speed)
            return nil
        } else {
            return getReplayImage(presentationTimeStamp)
        }
    }

    private func getReplayImage(_ presentationTimeStamp: Double) -> EffectImageCiImage? {
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
