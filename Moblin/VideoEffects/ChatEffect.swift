import Collections
import SwiftUI
import WrappingHStack

private let borderWidth = 1.5

private struct HighlightMessageView: View {
    let settings: SettingsWidgetChat
    let highlight: ChatHighlight

    private func backgroundColor() -> Color {
        if settings.backgroundColorEnabled {
            return settings.backgroundColor.color().opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if settings.shadowColorEnabled {
            return settings.shadowColor.color()
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
                        .foregroundStyle(highlight.messageColor(defaultColor: settings.messageColor.color()))
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
    let settings: SettingsWidgetChat
    let platform: Bool

    private func usernameColor() -> Color {
        return post.userColor.color()
    }

    private func messageColor(usernameColor _: Color) -> Color {
        return settings.messageColor.color()
    }

    private func backgroundColor() -> Color {
        if settings.backgroundColorEnabled {
            return settings.backgroundColor.color().opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if settings.shadowColorEnabled {
            return settings.shadowColor.color()
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
            ForEach(post.segments, id: \.id) { segment in
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

    var body: some View {
        if let highlight = post.highlight {
            HStack(spacing: 0) {
                Rectangle()
                    .frame(width: 3)
                    .foregroundStyle(highlight.barColor)
                VStack(alignment: .leading, spacing: 1) {
                    HighlightMessageView(settings: settings, highlight: highlight)
                    LineView(post: post, settings: settings, platform: true)
                }
            }
        } else {
            LineView(post: post, settings: settings, platform: true)
                .padding([.leading], 3)
        }
    }
}

private struct ChatView: View {
    let settings: SettingsWidgetChat
    let posts: Deque<ChatPost>

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Spacer()
            ForEach(posts) { post in
                HStack {
                    PostView(settings: settings, post: post)
                    Spacer()
                }
            }
        }
        .frame(width: 400)
        .foregroundStyle(.white)
    }
}

final class ChatEffect: VideoEffect {
    private var sceneWidget = SettingsSceneWidget(widgetId: .init())
    private var settings = SettingsWidgetChat()
    private var chatImage: CIImage?

    override func getName() -> String {
        return "chat"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setSettings(settings: SettingsWidgetChat) {
        self.settings = settings
    }

    func update(posts: Deque<ChatPost>) {
        DispatchQueue.main.async {
            let renderer = ImageRenderer(content: ChatView(settings: self.settings, posts: posts))
            guard let uiImage = renderer.uiImage else {
                return
            }
            self.setChatImage(image: CIImage(image: uiImage))
        }
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
