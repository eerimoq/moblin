import SDWebImage
import SwiftUI

private let maxFramesBytes = 32 * 1024 * 1024
private let unusedEmoteTimeout = 60.0
private let borderOffsetsCount = 16
private let borderWidthToHaloWidth = 2.0

struct EmoteBorder: Equatable {
    let color: Color
    let width: CGFloat
}

private struct EmoteKey: Hashable {
    let url: URL
    let height: Int
    let borderColor: UInt32
    let borderWidth: Int
}

private func packColor(color: Color) -> UInt32 {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return UInt32(red * 255) << 24 | UInt32(green * 255) << 16 | UInt32(blue * 255) << 8 | UInt32(alpha * 255)
}

private struct WeakEmoteUiView {
    weak var view: EmoteUiView?
}

private class AnimatedEmote {
    private let animatedImage: SDAnimatedImage?
    private let sourceImage: CGImage?
    private let width: Int
    private let height: Int
    private let borderColor: CGColor?
    private let borderWidth: CGFloat
    private var frames: [CGImage?]
    private var startTimes: [Double]
    private let totalDuration: Double
    private var currentIndex = -1
    private var views: [WeakEmoteUiView] = []
    private(set) var framesBytes = 0
    private(set) var lastUsedTime = CACurrentMediaTime()

    init(image: UIImage, key: EmoteKey, border: EmoteBorder?) {
        if let border, key.borderWidth > 0 {
            borderColor = UIColor(border.color).cgColor
            borderWidth = CGFloat(key.borderWidth)
        } else {
            borderColor = nil
            borderWidth = 0
        }
        height = key.height + 2 * key.borderWidth
        width = max(Int((CGFloat(key.height) * image.size.width / image.size.height).rounded()), 1)
            + 2 * key.borderWidth
        if let animatedImage = image as? SDAnimatedImage, animatedImage.animatedImageFrameCount > 1 {
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

    func add(view: EmoteUiView, time: Double) {
        views.append(WeakEmoteUiView(view: view))
        lastUsedTime = time
        if currentIndex == -1 {
            update(time: time)
        } else {
            view.setFrame(image: frames[currentIndex])
        }
    }

    func remove(view: EmoteUiView) {
        views.removeAll(where: { $0.view == nil || $0.view === view })
        lastUsedTime = CACurrentMediaTime()
    }

    func update(time: Double) {
        let index = frameIndex(time: time)
        guard index != currentIndex else {
            return
        }
        currentIndex = index
        let frame = frame(index: index)
        for view in views {
            view.view?.setFrame(image: frame)
        }
    }

    func clearFrames() {
        guard isAnimated() else {
            return
        }
        frames = Array(repeating: nil, count: frames.count)
        framesBytes = 0
        currentIndex = -1
    }

    private func frameIndex(time: Double) -> Int {
        guard totalDuration > 0 else {
            return 0
        }
        let offset = time.truncatingRemainder(dividingBy: totalDuration)
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
            framesBytes += frame.bytesPerRow * frame.height
        }
        return frame
    }

    private func render(sourceFrame: CGImage?) -> CGImage? {
        guard let sourceFrame else {
            return nil
        }
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return nil
        }
        context.interpolationQuality = .high
        let rect = CGRect(x: 0, y: 0, width: width, height: height).insetBy(dx: borderWidth, dy: borderWidth)
        if let borderColor {
            for index in 0 ..< borderOffsetsCount {
                let angle = Double(index) * 2 * .pi / Double(borderOffsetsCount)
                context.draw(sourceFrame, in: rect.offsetBy(dx: borderWidth * cos(angle),
                                                            dy: borderWidth * sin(angle)))
            }
            for index in 0 ..< borderOffsetsCount / 2 {
                let angle = Double(index) * 4 * .pi / Double(borderOffsetsCount)
                context.draw(sourceFrame, in: rect.offsetBy(dx: borderWidth * cos(angle) / 2,
                                                            dy: borderWidth * sin(angle) / 2))
            }
            context.setBlendMode(.sourceIn)
            context.setFillColor(borderColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.setBlendMode(.normal)
        }
        context.draw(sourceFrame, in: rect)
        return context.makeImage()
    }
}

private class EmotesPlayer: NSObject {
    static let shared = EmotesPlayer()
    private var emotes: [EmoteKey: AnimatedEmote] = [:]
    private var pendingViews: [EmoteKey: [WeakEmoteUiView]] = [:]
    private var sizes: [URL: CGSize] = [:]
    private var loadingHandlers: [URL: [(UIImage) -> Void]] = [:]
    private var displayLink: CADisplayLink?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMemoryWarning),
                                               name: UIApplication.didReceiveMemoryWarningNotification,
                                               object: nil)
    }

    func loadSize(url: URL, onLoaded: @escaping (CGSize) -> Void) {
        if let size = sizes[url] {
            DispatchQueue.main.async {
                onLoaded(size)
            }
        } else {
            load(url: url) { [weak self] image in
                self?.sizes[url] = image.size
                onLoaded(image.size)
            }
        }
    }

    func register(view: EmoteUiView, key: EmoteKey, border: EmoteBorder?) {
        if let emote = emotes[key] {
            emote.add(view: view, time: CACurrentMediaTime())
            updateDisplayLink()
        } else {
            pendingViews[key, default: []].append(WeakEmoteUiView(view: view))
            load(url: key.url) { [weak self] image in
                guard let self else {
                    return
                }
                let views = pendingViews.removeValue(forKey: key) ?? []
                guard !views.isEmpty else {
                    return
                }
                let emote = emotes[key] ?? AnimatedEmote(image: image, key: key, border: border)
                emotes[key] = emote
                let time = CACurrentMediaTime()
                for view in views.compactMap(\.view) {
                    emote.add(view: view, time: time)
                }
                updateDisplayLink()
            }
        }
    }

    func unregister(view: EmoteUiView, key: EmoteKey) {
        emotes[key]?.remove(view: view)
        pendingViews[key]?.removeAll(where: { $0.view == nil || $0.view === view })
        updateDisplayLink()
    }

    private func load(url: URL, onLoaded: @escaping (UIImage) -> Void) {
        if loadingHandlers[url] != nil {
            loadingHandlers[url]?.append(onLoaded)
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
            let handlers = loadingHandlers.removeValue(forKey: url) ?? []
            guard let image, image.size.width > 0, image.size.height > 0 else {
                return
            }
            for handler in handlers {
                handler(image)
            }
        }
    }

    private func updateDisplayLink() {
        let isAnimating = emotes.values.contains(where: { $0.isAnimated() && $0.isUsed() })
        if isAnimating, displayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 30)
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        } else if !isAnimating, displayLink != nil {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    @objc private func tick(displayLink: CADisplayLink) {
        let time = displayLink.timestamp
        var framesBytes = 0
        for emote in emotes.values where emote.isAnimated() {
            if emote.isUsed() {
                emote.update(time: time)
            }
            framesBytes += emote.framesBytes
        }
        if framesBytes > maxFramesBytes {
            evict(time: time)
        }
    }

    @objc private func handleMemoryWarning() {
        evict(time: CACurrentMediaTime())
    }

    private func evict(time: Double) {
        for (key, emote) in emotes where !emote.isUsed() {
            if time - emote.lastUsedTime > unusedEmoteTimeout {
                emotes.removeValue(forKey: key)
            } else {
                emote.clearFrames()
            }
        }
    }
}

private class EmoteUiView: UIView {
    var onSize: ((CGSize) -> Void)?
    private var url: URL?
    private var border: EmoteBorder?
    private var draw = false
    private var key: EmoteKey?
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

    func setEmote(url: URL, border: EmoteBorder?, draw: Bool) {
        if url != self.url {
            self.url = url
            EmotesPlayer.shared.loadSize(url: url) { [weak self] size in
                guard self?.url == url else {
                    return
                }
                self?.onSize?(size)
            }
        }
        self.border = border
        self.draw = draw
        updateKey()
    }

    func unregister() {
        if let key {
            EmotesPlayer.shared.unregister(view: self, key: key)
            self.key = nil
        }
    }

    func setFrame(image: CGImage?) {
        contentLayer.contents = image
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let halo = (border?.width ?? 0) * borderWidthToHaloWidth
        contentLayer.frame = bounds.insetBy(dx: -halo, dy: -halo)
        updateKey()
    }

    private func updateKey() {
        guard let url, draw else {
            unregister()
            setFrame(image: nil)
            return
        }
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 1
        let height = Int((bounds.height * scale).rounded())
        guard height > 0 else {
            return
        }
        let key = EmoteKey(url: url,
                           height: height,
                           borderColor: border.map { packColor(color: $0.color) } ?? 0,
                           borderWidth: Int(((border?.width ?? 0) * borderWidthToHaloWidth * scale)
                               .rounded()))
        guard key != self.key else {
            return
        }
        unregister()
        self.key = key
        EmotesPlayer.shared.register(view: self, key: key, border: border)
    }
}

private class AnimatedEmoteState: ObservableObject {
    @Published var size: CGSize?
}

private struct AnimatedEmoteViewRepresentable: UIViewRepresentable {
    let url: URL
    let border: EmoteBorder?
    let draw: Bool
    @ObservedObject var state: AnimatedEmoteState

    func makeUIView(context _: Context) -> EmoteUiView {
        let view = EmoteUiView()
        view.onSize = { [weak state] size in
            guard state?.size != size else {
                return
            }
            state?.size = size
        }
        view.setEmote(url: url, border: border, draw: draw)
        return view
    }

    func updateUIView(_ view: EmoteUiView, context _: Context) {
        view.setEmote(url: url, border: border, draw: draw)
    }

    static func dismantleUIView(_ view: EmoteUiView, coordinator _: ()) {
        view.unregister()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView _: EmoteUiView, context _: Context) -> CGSize? {
        guard let size = state.size, size.width > 0, size.height > 0 else {
            return CGSize(width: 0, height: 0)
        }
        if let height = proposal.height, height.isFinite {
            return CGSize(width: height * size.width / size.height, height: height)
        }
        if let width = proposal.width, width.isFinite {
            return CGSize(width: width, height: width * size.height / size.width)
        }
        return size
    }
}

struct AnimatedEmoteView: View {
    let url: URL
    var border: EmoteBorder?
    var mask = false
    @StateObject private var state = AnimatedEmoteState()

    var body: some View {
        AnimatedEmoteViewRepresentable(url: url, border: mask ? nil : border, draw: !mask, state: state)
    }
}
