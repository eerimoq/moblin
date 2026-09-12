import SDWebImage
import SwiftUI

private let maxFramesBytes = 256 * 1024 * 1024

enum ChatImageSource: Hashable {
    case url(URL)
    case asset(String)
    case symbol(String, CGFloat, UIColor)
}

private struct EmoteBorder: Hashable {
    let color: UIColor
    let width: Int
}

private struct EmoteKey: Hashable {
    let source: ChatImageSource
    let animated: Bool
    let height: Int
    let border: EmoteBorder?
}

private struct WeakEmoteUiView {
    weak var view: EmoteUiView?
}

private func makeBitmapContext(width: Int, height: Int) -> CGContext? {
    CGContext(data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
}

@MainActor
private class AnimatedEmote {
    private unowned let player: EmotesPlayer
    private let animatedImage: SDAnimatedImage?
    private let sourceImage: CGImage?
    private let width: Int
    private let height: Int
    private let border: EmoteBorder?
    private let contentRect: CGRect
    private let startTime = ContinuousClock.now
    private var frames: [CGImage?]
    private var startTimes: [Double]
    private let totalDuration: Double
    private var currentIndex = -1
    private var views: [WeakEmoteUiView] = []
    private var contentContext: CGContext?
    private var renderedFrames = 0
    private(set) var framesBytes = 0
    private(set) var lastUsedTime = ContinuousClock.now

    init(player: EmotesPlayer, image: UIImage, key: EmoteKey) {
        self.player = player
        border = key.border
        height = key.height
        let borderWidth = key.border?.width ?? 0
        let contentHeight = max(height - 2 * borderWidth, 1)
        let aspectRatio = image.size.height > 0 ? image.size.width / image.size.height : 1
        let contentWidth = max(Int((CGFloat(contentHeight) * aspectRatio).rounded()), 1)
        contentRect = CGRect(x: borderWidth, y: borderWidth, width: contentWidth, height: contentHeight)
        width = contentWidth + 2 * borderWidth
        if key.animated, let animatedImage = image as? SDAnimatedImage,
           animatedImage.animatedImageFrameCount > 1
        {
            self.animatedImage = animatedImage
            sourceImage = nil
            let frameCount = Int(animatedImage.animatedImageFrameCount)
            frames = Array(repeating: nil, count: frameCount)
            startTimes = []
            var time = 0.0
            for index in 0 ..< frameCount {
                startTimes.append(time)
                time += max(animatedImage.animatedImageDuration(at: UInt(index)), 0.01)
            }
            totalDuration = time
        } else {
            animatedImage = nil
            sourceImage = image.cgImage
            frames = [nil]
            startTimes = [0]
            totalDuration = 0
        }
    }

    func isAnimated() -> Bool {
        animatedImage != nil
    }

    func isUsed() -> Bool {
        views.removeAll(where: { $0.view == nil })
        return !views.isEmpty
    }

    func add(view: EmoteUiView, now: ContinuousClock.Instant) {
        views.append(WeakEmoteUiView(view: view))
        lastUsedTime = now
        if currentIndex == -1 {
            update(now: now)
        } else {
            view.setFrame(image: frames[currentIndex])
        }
    }

    func remove(view: EmoteUiView) {
        views.removeAll(where: { $0.view == nil || $0.view === view })
        lastUsedTime = .now
    }

    func update(now: ContinuousClock.Instant) {
        let index = frameIndex(now: now)
        guard index != currentIndex else {
            return
        }
        currentIndex = index
        let frame = frame(index: index)
        for view in views {
            view.view?.setFrame(image: frame)
        }
    }

    private func frameIndex(now: ContinuousClock.Instant) -> Int {
        guard totalDuration > 0 else {
            return 0
        }
        let offset = startTime.duration(to: now).seconds.truncatingRemainder(dividingBy: totalDuration)
        var index = startTimes.count - 1
        while index > 0, startTimes[index] > offset {
            index -= 1
        }
        return index
    }

    private func frame(index: Int) -> CGImage? {
        if let frame = frames[index] {
            return frame
        }
        let sourceFrame = animatedImage?.animatedImageFrame(at: UInt(index))?.cgImage ?? sourceImage
        let frame = render(sourceFrame: sourceFrame)
        frames[index] = frame
        if let frame {
            let bytes = frame.bytesPerRow * frame.height
            framesBytes += bytes
            player.addFramesBytes(bytes)
            renderedFrames += 1
            if renderedFrames == frames.count {
                contentContext = nil
            }
        }
        return frame
    }

    private func render(sourceFrame: CGImage?) -> CGImage? {
        guard let sourceFrame else {
            return nil
        }
        guard let border else {
            guard let context = makeBitmapContext(width: width, height: height) else {
                return nil
            }
            context.interpolationQuality = .high
            context.draw(sourceFrame, in: contentRect)
            return context.makeImage()
        }
        guard let content = renderContent(sourceFrame: sourceFrame),
              let context = makeBitmapContext(width: width, height: height)
        else {
            return nil
        }
        let straight = CGFloat(border.width)
        let diagonal = (straight * 0.7).rounded()
        for (dx, dy) in [
            (straight, 0),
            (-straight, 0),
            (0, straight),
            (0, -straight),
            (diagonal, diagonal),
            (diagonal, -diagonal),
            (-diagonal, diagonal),
            (-diagonal, -diagonal),
        ] {
            context.draw(content, in: contentRect.offsetBy(dx: dx, dy: dy))
        }
        context.setBlendMode(.sourceIn)
        context.setFillColor(border.color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setBlendMode(.normal)
        context.draw(content, in: contentRect)
        return context.makeImage()
    }

    private func renderContent(sourceFrame: CGImage) -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: contentRect.width, height: contentRect.height)
        if contentContext == nil {
            contentContext = makeBitmapContext(width: Int(rect.width), height: Int(rect.height))
            contentContext?.interpolationQuality = .high
        }
        guard let contentContext else {
            return nil
        }
        contentContext.clear(rect)
        contentContext.draw(sourceFrame, in: rect)
        return contentContext.makeImage()
    }
}

@MainActor
class EmotesPlayer: NSObject, ObservableObject {
    static let shared = EmotesPlayer()
    @Published private(set) var sizesVersion = 0
    private var emotes: [EmoteKey: AnimatedEmote] = [:]
    private var animatingEmotes: [EmoteKey: AnimatedEmote] = [:]
    private var framesBytes = 0
    private var latestEvictTime = ContinuousClock.now
    private var pendingViews: [EmoteKey: [WeakEmoteUiView]] = [:]
    private var sizes: [ChatImageSource: CGSize] = [:]
    private var localImages: [ChatImageSource: UIImage] = [:]
    private var loadingHandlers: [URL: [(UIImage) -> Void]] = [:]
    private var failedUrls: [URL: ContinuousClock.Instant] = [:]
    private var displayLink: CADisplayLink?

    func size(source: ChatImageSource) -> CGSize? {
        if let size = sizes[source] {
            return size
        }
        var loading = true
        load(source: source) { [weak self] image in
            guard let self, sizes[source] == nil else {
                return
            }
            sizes[source] = image.size
            if !loading {
                sizesVersion += 1
            }
        }
        loading = false
        return sizes[source]
    }

    fileprivate func register(view: EmoteUiView, key: EmoteKey) {
        if let emote = emotes[key] {
            emote.add(view: view, now: .now)
            startAnimating(key: key, emote: emote)
        } else {
            pendingViews[key, default: []].append(WeakEmoteUiView(view: view))
            load(source: key.source) { [weak self] image in
                guard let self else {
                    return
                }
                let views = pendingViews.removeValue(forKey: key) ?? []
                guard !views.isEmpty else {
                    return
                }
                let emote = emotes[key] ?? AnimatedEmote(player: self, image: image, key: key)
                emotes[key] = emote
                let now = ContinuousClock.now
                for view in views.compactMap(\.view) {
                    emote.add(view: view, now: now)
                }
                startAnimating(key: key, emote: emote)
                evictIfNeeded(now: now)
            }
        }
    }

    fileprivate func unregister(view: EmoteUiView, key: EmoteKey) {
        if let emote = emotes[key] {
            emote.remove(view: view)
            if !emote.isUsed() {
                animatingEmotes.removeValue(forKey: key)
            }
        }
        pendingViews[key]?.removeAll(where: { $0.view == nil || $0.view === view })
        updateDisplayLink()
    }

    fileprivate func addFramesBytes(_ bytes: Int) {
        framesBytes += bytes
    }

    private func removeFramesBytes(_ bytes: Int) {
        framesBytes -= bytes
    }

    private func startAnimating(key: EmoteKey, emote: AnimatedEmote) {
        if emote.isAnimated() {
            animatingEmotes[key] = emote
        }
        updateDisplayLink()
    }

    private func load(source: ChatImageSource, onLoaded: @escaping (UIImage) -> Void) {
        if case let .url(url) = source {
            load(url: url, onLoaded: onLoaded)
            return
        }
        if let image = localImages[source] {
            onLoaded(image)
            return
        }
        guard let image = render(source: source) else {
            return
        }
        localImages[source] = image
        onLoaded(image)
    }

    private func render(source: ChatImageSource) -> UIImage? {
        switch source {
        case .url:
            return nil
        case let .asset(name):
            return UIImage(named: name)
        case let .symbol(name, size, color):
            let configuration = UIImage.SymbolConfiguration(pointSize: size)
            guard let symbol = UIImage(systemName: name, withConfiguration: configuration)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
            else {
                return nil
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = false
            return UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in
                symbol.draw(at: .zero)
            }
        }
    }

    private func load(url: URL, onLoaded: @escaping (UIImage) -> Void) {
        if loadingHandlers[url] != nil {
            loadingHandlers[url]?.append(onLoaded)
            return
        }
        if let failedTime = failedUrls[url], failedTime.duration(to: .now) < .seconds(60) {
            return
        }
        loadingHandlers[url] = [onLoaded]
        SDWebImageManager.shared.loadImage(with: url,
                                           options: [.retryFailed],
                                           context: [.animatedImageClass: SDAnimatedImage.self],
                                           progress: nil)
        { [weak self] image, _, _, _, _, _ in
            guard let self else {
                return
            }
            MainActor.assumeIsolated {
                let handlers = self.loadingHandlers.removeValue(forKey: url) ?? []
                guard let image, image.size.width > 0, image.size.height > 0 else {
                    self.failedUrls[url] = .now
                    return
                }
                self.failedUrls.removeValue(forKey: url)
                for handler in handlers {
                    handler(image)
                }
            }
        }
    }

    private func updateDisplayLink() {
        let isAnimating = !animatingEmotes.isEmpty
        if isAnimating, displayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 15, preferred: 15)
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        } else if !isAnimating, displayLink != nil {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    @objc private func tick() {
        let now = ContinuousClock.now
        var unusedKeys: [EmoteKey] = []
        for (key, emote) in animatingEmotes {
            if emote.isUsed() {
                emote.update(now: now)
            } else {
                unusedKeys.append(key)
            }
        }
        for key in unusedKeys {
            animatingEmotes.removeValue(forKey: key)
        }
        if !unusedKeys.isEmpty {
            updateDisplayLink()
        }
        evictIfNeeded(now: now)
    }

    private func evictIfNeeded(now: ContinuousClock.Instant) {
        guard framesBytes > maxFramesBytes, latestEvictTime.duration(to: now) > .seconds(1) else {
            return
        }
        latestEvictTime = now
        localImages.removeAll()
        let oldest = emotes
            .filter { !$0.value.isUsed() }
            .sorted { $0.value.lastUsedTime < $1.value.lastUsedTime }
            .prefix(50)
        logger.debug("emotes-player: Evicting \(oldest.count) emotes")
        for (key, emote) in oldest {
            emotes.removeValue(forKey: key)
            animatingEmotes.removeValue(forKey: key)
            removeFramesBytes(emote.framesBytes)
        }
    }
}

class EmoteUiView: UIView {
    var onLoaded: (() -> Void)?
    private var source: ChatImageSource?
    private var animated = true
    private var borderColor: UIColor?
    private var borderWidth: CGFloat = 0
    private var key: EmoteKey?
    private var loaded = false
    private let contentLayer = CALayer()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        contentLayer.contentsGravity = .resize
        contentLayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer.addSublayer(contentLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setEmote(source: ChatImageSource,
                  animated: Bool = true,
                  borderColor: UIColor? = nil,
                  borderWidth: CGFloat = 0)
    {
        self.source = source
        self.animated = animated
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        updateKey()
    }

    func unregister() {
        if let key {
            EmotesPlayer.shared.unregister(view: self, key: key)
            self.key = nil
        }
    }

    fileprivate func setFrame(image: CGImage?) {
        contentLayer.contents = image
        if image != nil, !loaded {
            loaded = true
            onLoaded?()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentLayer.frame = bounds
        updateKey()
    }

    private func updateKey() {
        guard let source else {
            unregister()
            setFrame(image: nil)
            return
        }
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 1
        let height = Int((bounds.height * scale).rounded())
        guard height > 0 else {
            return
        }
        var border: EmoteBorder?
        if let borderColor, borderWidth > 0 {
            border = EmoteBorder(color: borderColor, width: Int((borderWidth * scale).rounded()))
        }
        let key = EmoteKey(source: source, animated: animated, height: height, border: border)
        guard key != self.key else {
            return
        }
        unregister()
        self.key = key
        loaded = false
        EmotesPlayer.shared.register(view: self, key: key)
    }
}
