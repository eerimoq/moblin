import Collections
import Combine
import SwiftUI
import WrappingHStack

private let borderWidth = 1.5

private struct HighlightMessageView: View {
    @ObservedObject var settings: SettingsWidgetChat
    let highlight: ChatHighlight

    private func backgroundColor() -> Color {
        if settings.backgroundColorEnabled {
            return settings.backgroundColorColor.opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if settings.shadowColorEnabled {
            return settings.shadowColorColor
        } else {
            return .clear
        }
    }

    private func frameHeightEmotes() -> CGFloat {
        return CGFloat(settings.fontSize * 1.7)
    }

    var body: some View {
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Image(systemName: highlight.image)
            Text(" ")
            ForEach(highlight.titleSegments, id: \.id) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundStyle(highlight.messageColor(defaultColor: settings.messageColorColor))
                }
                if let url = segment.url {
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        EmptyView()
                    }
                    .padding([.top, .bottom], settings.shadowColorEnabled ? 1.5 : 0)
                    .frame(height: frameHeightEmotes())
                }
            }
        }
        .stroke(color: shadowColor(), width: settings.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(settings.fontSize)))
        .background(backgroundColor())
        .foregroundStyle(.white)
        .cornerRadius(5)
    }
}

private struct LineView: View {
    let post: ChatPost
    @ObservedObject var settings: SettingsWidgetChat
    let platform: Bool

    private func usernameColor() -> Color {
        return post.userColor.color()
    }

    private func messageColor(usernameColor _: Color) -> Color {
        return settings.messageColorColor
    }

    private func backgroundColor() -> Color {
        if settings.backgroundColorEnabled {
            return settings.backgroundColorColor.opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if settings.shadowColorEnabled {
            return settings.shadowColorColor
        } else {
            return .clear
        }
    }

    private func frameHeightBadges() -> CGFloat {
        return CGFloat(settings.fontSize * 1.4)
    }

    private func frameHeightEmotes() -> CGFloat {
        return CGFloat(settings.fontSize * 1.7)
    }

    var body: some View {
        let usernameColor = usernameColor()
        let messageColor = messageColor(usernameColor: usernameColor)
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if settings.platform, platform, let image = post.platform?.imageName() {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
                    .frame(height: frameHeightBadges())
            }
            if settings.badges {
                ForEach(post.userBadges, id: \.self) { url in
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(2)
                    .frame(height: frameHeightBadges())
                }
            }
            Text(post.displayName(nicknames: settings.nicknames, displayStyle: settings.displayStyle))
                .foregroundStyle(usernameColor)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold(settings.boldUsername)
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundStyle(messageColor)
                        .bold(settings.boldMessage)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        EmptyView()
                    }
                    .padding([.top, .bottom], settings.shadowColorEnabled ? 1.5 : 0)
                    .frame(height: frameHeightEmotes())
                    Text(" ")
                }
            }
        }
        .stroke(color: shadowColor(), width: settings.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(settings.fontSize)))
        .background(backgroundColor())
        .foregroundStyle(.white)
        .cornerRadius(5)
    }
}

private struct PostView: View {
    let settings: SettingsWidgetChat
    let post: ChatPost
    @ObservedObject var state: ChatPostState
    let moreThanOneStreamingPlatform: Bool

    var body: some View {
        if !state.deleted {
            if let highlight = post.highlight {
                HStack(spacing: 0) {
                    Rectangle()
                        .frame(width: 3)
                        .foregroundStyle(highlight.barColor)
                    VStack(alignment: .leading, spacing: 1) {
                        HighlightMessageView(settings: settings, highlight: highlight)
                        LineView(post: post, settings: settings, platform: moreThanOneStreamingPlatform)
                    }
                }
            } else {
                LineView(post: post, settings: settings, platform: moreThanOneStreamingPlatform)
                    .padding([.leading], 3)
            }
        }
    }
}

private struct ChatView: View {
    @ObservedObject var settings: SettingsWidgetChat
    @ObservedObject var chat: ChatProvider

    private func width() -> Double {
        return 20 * Double(settings.fontSize)
    }

    var body: some View {
        VStack(spacing: 1) {
            Spacer()
            ForEach(chat.posts.reversed()) { post in
                HStack {
                    PostView(settings: settings,
                             post: post,
                             state: post.state,
                             moreThanOneStreamingPlatform: chat.moreThanOneStreamingPlatform)
                    Spacer()
                }
            }
        }
        .frame(width: width())
        .foregroundStyle(.white)
    }
}

final class ChatEffect: VideoEffect, ObservableObject {
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var chatImage: CIImage?
    private var renderer: ImageRenderer<ChatView>?
    private var settings = SettingsWidgetChat()
    private let chat: ChatProvider
    private var cancellable: AnyCancellable?
    private var started: Bool = false

    init(chat: ChatProvider) {
        self.chat = chat
    }

    override func getName() -> String {
        return "Chat"
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        DispatchQueue.main.async {
            self.startInner()
        }
    }

    func stop() {
        guard started else {
            return
        }
        started = false
        DispatchQueue.main.async {
            self.stopInner()
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setSettings(settings: SettingsWidgetChat) {
        self.settings.update(other: settings)
    }

    @MainActor
    private func startInner() {
        renderer = ImageRenderer(content: ChatView(settings: settings, chat: chat))
        cancellable = renderer?.objectWillChange.sink { [weak self] in
            guard let self else {
                return
            }
            self.setChatImage(image: self.renderer?.ciImage())
        }
        setChatImage(image: renderer?.ciImage())
    }

    private func stopInner() {
        renderer = nil
        cancellable = nil
    }

    private func setChatImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.chatImage = image
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return chatImage?
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }
}
