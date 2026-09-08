import Collections
import Combine
import MetalPetal
import SwiftUI

private func makeChatLineStyle(settings: SettingsWidgetChat) -> ChatLineStyle {
    ChatLineStyle(
        fontSize: CGFloat(settings.fontSize),
        borderColor: settings.shadowColorEnabled ? settings.shadowColor.uiColor() : nil,
        borderWidth: 1.5,
        backgroundColor: settings.backgroundColorEnabled ? settings.backgroundColor.uiColor()
            .withAlphaComponent(0.6) : nil,
        messageColor: settings.messageColor.uiColor(),
        boldUsername: settings.boldUsername,
        boldMessage: settings.boldMessage,
        badges: settings.badges,
        sharedChatIcons: settings.sharedChatIcons,
        bigGifScale: 3,
        highlightSymbolColor: .white,
        highlightDefaultColor: settings.messageColorColor,
        nicknames: settings.nicknames,
        displayStyle: settings.displayStyle
    )
}

@MainActor
private class ChatRenderer {
    private let settings: SettingsWidgetChat
    private let chat: ChatProvider
    private let onImage: (CGImage?) -> Void
    private let containerView = UIView()
    private var lineViews: [ChatLineUiView] = []
    private var barLayers: [CALayer] = []
    private var cancellables: [AnyCancellable] = []
    private var stateCancellables: [AnyCancellable] = []
    private var renderPending = false

    private var width: CGFloat {
        20 * CGFloat(settings.fontSize)
    }

    init(settings: SettingsWidgetChat, chat: ChatProvider, onImage: @escaping (CGImage?) -> Void) {
        self.settings = settings
        self.chat = chat
        self.onImage = onImage
        containerView.backgroundColor = .clear
        chat.$posts
            .sink { [weak self] _ in
                self?.scheduleRender()
            }
            .store(in: &cancellables)
        chat.$moreThanOneStreamingPlatform
            .sink { [weak self] _ in
                self?.scheduleRender()
            }
            .store(in: &cancellables)
        settings.objectWillChange
            .sink { [weak self] _ in
                self?.scheduleRender()
            }
            .store(in: &cancellables)
        EmotesPlayer.shared.$sizesVersion
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRender()
            }
            .store(in: &cancellables)
        scheduleRender()
    }

    func stop() {
        cancellables = []
        stateCancellables = []
        for lineView in lineViews {
            lineView.unregister()
        }
    }

    private func scheduleRender() {
        guard !renderPending else {
            return
        }
        renderPending = true
        DispatchQueue.main.async { [weak self] in
            self?.renderPending = false
            self?.render()
        }
    }

    private func lineView(index: Int) -> ChatLineUiView {
        while lineViews.count <= index {
            let lineView = ChatLineUiView()
            lineView.onImageLoaded = { [weak self] in
                self?.scheduleRender()
            }
            containerView.addSubview(lineView)
            lineViews.append(lineView)
        }
        return lineViews[index]
    }

    private func barLayer(index: Int) -> CALayer {
        while barLayers.count <= index {
            let barLayer = CALayer()
            barLayer.actions = ["bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull()]
            containerView.layer.addSublayer(barLayer)
            barLayers.append(barLayer)
        }
        return barLayers[index]
    }

    private func place(lineView: ChatLineUiView,
                       content: ChatLineContent,
                       x: CGFloat,
                       y: CGFloat) -> CGSize
    {
        lineView.setContent(content)
        let size = lineView.size(availableWidth: width - x)
        lineView.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
        return size
    }

    private func render() {
        let posts = chat.posts.prefix(settings.maximumNumberOfMessages).reversed()
            .filter { !$0.state.deleted }
        stateCancellables = posts.map { post in
            post.state.objectWillChange.sink { [weak self] _ in
                self?.scheduleRender()
            }
        }
        let style = makeChatLineStyle(settings: settings)
        var lineIndex = 0
        var barIndex = 0
        var y: CGFloat = 0
        for (index, post) in posts.enumerated() {
            if index > 0 {
                y += 1
            }
            let startY = y
            var x: CGFloat = 3
            var highlightImageLineView: ChatLineUiView?
            var highlightImageSize = CGSize.zero
            if let highlight = post.highlight {
                var highlightStyle = style
                highlightStyle.backgroundColor = nil
                let lineView = lineView(index: lineIndex)
                lineView.setContent(highlightStyle.makeHighlightImageContent(highlight: highlight))
                highlightImageSize = lineView.size(availableWidth: width - x)
                highlightImageLineView = lineView
                lineIndex += 1
                x += highlightImageSize.width
            }
            let content = style.makeContent(post: post,
                                            platform: chat.moreThanOneStreamingPlatform,
                                            deleted: false)
            let size = place(lineView: lineView(index: lineIndex), content: content, x: x, y: y)
            lineIndex += 1
            highlightImageLineView?.frame = CGRect(x: 3,
                                                   y: y + (size.height - highlightImageSize.height) / 2,
                                                   width: highlightImageSize.width,
                                                   height: highlightImageSize.height)
            y += size.height
            if let highlight = post.highlight {
                let barLayer = barLayer(index: barIndex)
                barLayer.backgroundColor = UIColor(highlight.barColor).cgColor
                barLayer.frame = CGRect(x: 0, y: startY, width: 3, height: y - startY)
                barIndex += 1
            }
        }
        while lineViews.count > lineIndex {
            let lineView = lineViews.removeLast()
            lineView.unregister()
            lineView.removeFromSuperview()
        }
        while barLayers.count > barIndex {
            barLayers.removeLast().removeFromSuperlayer()
        }
        guard y > 0 else {
            onImage(nil)
            return
        }
        containerView.frame = CGRect(x: 0, y: 0, width: width, height: y)
        containerView.layoutIfNeeded()
        for lineView in lineViews {
            lineView.layer.displayIfNeeded()
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: containerView.bounds.size, format: format)
            .image { context in
                containerView.layer.render(in: context.cgContext)
            }
        onImage(image.cgImage)
    }
}

final class ChatEffect: VideoEffect, @unchecked Sendable {
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var chatImage: EffectImageCgImage?
    private var renderer: ChatRenderer?
    private var settings = SettingsWidgetChat()
    private var height: Double = 1
    private let chat: ChatProvider
    private var started: Bool = false

    init(chat: ChatProvider) {
        self.chat = chat
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        DispatchQueue.main.async {
            self.startInternal()
        }
    }

    func stop() {
        guard started else {
            return
        }
        started = false
        DispatchQueue.main.async {
            self.stopInternal()
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setSettings(settings: SettingsWidgetChat) {
        self.settings.update(other: settings)
        let maximumHeight = settings.height
        processorPipelineQueue.async {
            self.height = Double(maximumHeight)
        }
    }

    @MainActor
    private func startInternal() {
        renderer = ChatRenderer(settings: settings, chat: chat) { [weak self] image in
            self?.setChatImage(image: image)
        }
    }

    @MainActor
    private func stopInternal() {
        renderer?.stop()
        renderer = nil
    }

    private func setChatImage(image: CGImage?) {
        let chatImage = image?.toEffectImage()
        processorPipelineQueue.async {
            self.chatImage = chatImage
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard var chatImage = chatImage?.getCiImage() else {
            return image
        }
        let height = Double(image.extent.height) * height
        if chatImage.extent.height > height {
            chatImage = chatImage.cropped(to: CGRect(
                x: chatImage.extent.minX,
                y: chatImage.extent.minY,
                width: chatImage.extent.width,
                height: height
            ))
        }
        return chatImage
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        guard let chatImage = chatImage?.getMetalPetalImage() else {
            return image
        }
        var contentRegion = chatImage.extent
        let height = Double(image.extent.height) * height
        if contentRegion.height > height {
            contentRegion = CGRect(x: contentRegion.minX,
                                   y: contentRegion.maxY - height,
                                   width: contentRegion.width,
                                   height: height)
        }
        return chatImage.moveComposited(sceneWidget.layout, image, contentRegion)
    }
}
