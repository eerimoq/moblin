import Collections
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

private let borderWidth = 1.5

private struct HighlightMessageView: View {
    let chat: SettingsChat
    let image: String
    let name: String

    private func messageColor() -> Color {
        return chat.messageColor.color()
    }

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            return chat.backgroundColor.color().opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            return chat.shadowColor.color()
        } else {
            return .clear
        }
    }

    var body: some View {
        let messageColor = messageColor()
        let shadowColor = shadowColor()
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Image(systemName: image)
            Text(" ")
            Text(name)
        }
        .foregroundColor(messageColor)
        .stroke(color: shadowColor, width: chat.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

private struct LineView: View {
    var post: ChatPost
    var chat: SettingsChat

    private func usernameColor() -> Color {
        if let color = post.userColor {
            return color.color()
        } else {
            return chat.usernameColor.color()
        }
    }

    private func messageColor(usernameColor: Color) -> Color {
        if post.isAction && chat.meInUsernameColor! {
            return usernameColor
        } else {
            return chat.messageColor.color()
        }
    }

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            return chat.backgroundColor.color().opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            return chat.shadowColor.color()
        } else {
            return .clear
        }
    }

    var body: some View {
        let timestampColor = chat.timestampColor.color()
        let usernameColor = usernameColor()
        let messageColor = messageColor(usernameColor: usernameColor)
        let shadowColor = shadowColor()
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chat.timestampColorEnabled {
                Text("\(post.timestamp) ")
                    .foregroundColor(timestampColor)
            }
            if chat.badges! {
                ForEach(post.userBadges, id: \.self) { url in
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        EmptyView()
                    }
                    .padding(2)
                    .frame(height: CGFloat(chat.fontSize * 1.4))
                }
            }
            Text(post.user!)
                .foregroundColor(usernameColor)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold(chat.boldUsername)
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments, id: \.id) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundColor(messageColor)
                        .bold(chat.boldMessage)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                            .frame(height: CGFloat(chat.fontSize * 1.7))
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .padding([.top, .bottom], chat.shadowColorEnabled ? 1.5 : 0)
                        .frame(height: CGFloat(chat.fontSize * 1.7))
                    }
                    Text(" ")
                }
            }
        }
        .stroke(color: shadowColor, width: chat.shadowColorEnabled ? borderWidth : 0)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private var previousOffset = 0.0

struct StreamOverlayChatView: View {
    @EnvironmentObject var model: Model
    private let spaceName = "scroll"
    @State var wholeSize: CGSize = .zero
    @State var scrollViewSize: CGSize = .zero

    private func getRotation() -> Double {
        if model.database.chat.newMessagesAtTop! {
            return 0.0
        } else {
            return 180.0
        }
    }

    private func getScaleX() -> Double {
        if model.database.chat.newMessagesAtTop! {
            return 1.0
        } else {
            return -1.0
        }
    }

    private func isCloseToStart(offset: Double) -> Bool {
        if model.database.chat.newMessagesAtTop! {
            return offset < 50
        } else {
            return offset >= scrollViewSize.height - wholeSize.height - 50.0
        }
    }

    private func isMirrored() -> CGFloat {
        if model.database.chat.mirrored! {
            return -1
        } else {
            return 1
        }
    }

    var body: some View {
        let rotation = getRotation()
        let scaleX = getScaleX()
        GeometryReader { metrics in
            VStack {
                Spacer()
                ChildSizeReader(size: $wholeSize) {
                    ScrollView(showsIndicators: false) {
                        ChildSizeReader(size: $scrollViewSize) {
                            VStack {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(model.chatPosts) { post in
                                        if post.user != nil {
                                            if let highlight = post.highlight {
                                                HStack(spacing: 0) {
                                                    Rectangle()
                                                        .frame(width: 3)
                                                        .foregroundColor(highlight.color)
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        HighlightMessageView(
                                                            chat: model.database.chat,
                                                            image: highlight.image,
                                                            name: highlight.title
                                                        )
                                                        LineView(
                                                            post: post,
                                                            chat: model.database.chat
                                                        )
                                                    }
                                                }
                                                .rotationEffect(Angle(degrees: rotation))
                                                .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                            } else {
                                                LineView(post: post, chat: model.database.chat)
                                                    .padding([.leading], 3)
                                                    .rotationEffect(Angle(degrees: rotation))
                                                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                            }
                                        } else {
                                            Rectangle()
                                                .fill(.red)
                                                .frame(width: metrics.size.width, height: 1.5)
                                                .padding(2)
                                                .rotationEffect(Angle(degrees: rotation))
                                                .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                        }
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: ViewOffsetKey.self,
                                        value: -1 * proxy.frame(in: .named(spaceName)).origin.y
                                    )
                                }
                            )
                            .onPreferenceChange(
                                ViewOffsetKey.self,
                                perform: { scrollViewOffsetFromTop in
                                    let offset = max(scrollViewOffsetFromTop, 0)
                                    if isCloseToStart(offset: offset) {
                                        if model.chatPaused, offset >= previousOffset {
                                            model.endOfChatReachedWhenPaused()
                                        }
                                    } else if !model.chatPaused {
                                        if !model.chatPosts.isEmpty {
                                            model.pauseChat()
                                        }
                                    }
                                    previousOffset = offset
                                }
                            )
                            .frame(minHeight: metrics.size.height)
                        }
                    }
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: rotation))
                    .scaleEffect(x: scaleX * isMirrored(), y: 1.0, anchor: .center)
                    .coordinateSpace(name: spaceName)
                    .frame(width: metrics.size.width * model.database.chat.width!,
                           height: metrics.size.height * model.database.chat.height!)
                }
            }
        }
    }
}
