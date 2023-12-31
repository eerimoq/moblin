import Collections
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

struct AnnouncementView: View {
    var chat: SettingsChat

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
            Image(systemName: "horn.blast")
            Text(" ")
            Text("Announcement")
        }
        .foregroundColor(messageColor)
        .shadow(color: shadowColor, radius: 0, x: 1.5, y: 0.0)
        .shadow(color: shadowColor, radius: 0, x: -1.5, y: 0.0)
        .shadow(color: shadowColor, radius: 0, x: 0.0, y: 1.5)
        .shadow(color: shadowColor, radius: 0, x: 0.0, y: -1.5)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

struct FirstMessageView: View {
    var chat: SettingsChat

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
            Image(systemName: "bubble.left")
            Text(" ")
            Text("First time chatter")
        }
        .foregroundColor(messageColor)
        .shadow(color: shadowColor, radius: 0, x: 1.5, y: 0.0)
        .shadow(color: shadowColor, radius: 0, x: -1.5, y: 0.0)
        .shadow(color: shadowColor, radius: 0, x: 0.0, y: 1.5)
        .shadow(color: shadowColor, radius: 0, x: 0.0, y: -1.5)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

struct LineView: View {
    var post: ChatPost
    var chat: SettingsChat

    private func usernameColor() -> Color {
        if let userColor = post.userColor, let colorNumber = Int(
            userColor.suffix(6),
            radix: 16
        ) {
            let color = RgbColor(
                red: (colorNumber >> 16) & 0xFF,
                green: (colorNumber >> 8) & 0xFF,
                blue: colorNumber & 0xFF
            )
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
            Text(post.user!)
                .foregroundColor(usernameColor)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold(chat.boldUsername)
            Text(": ")
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
        .shadow(color: shadowColor, radius: 0, x: 1.5, y: 0.0)
        .shadow(color: shadowColor, radius: 0, x: -1.5, y: 0.0)
        .shadow(color: shadowColor, radius: 0, x: 0.0, y: 1.5)
        .shadow(color: shadowColor, radius: 0, x: 0.0, y: -1.5)
        .padding([.leading], 5)
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

struct StreamOverlayChatView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        GeometryReader { fullMetrics in
            VStack {
                Spacer(minLength: 0)
                GeometryReader { metrics in
                    ScrollView {
                        ScrollViewReader { reader in
                            VStack {
                                Spacer(minLength: 0)
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(model.chatPosts) { post in
                                        if post.user != nil {
                                            if post.isAnnouncement {
                                                HStack(spacing: 0) {
                                                    Rectangle()
                                                        .frame(width: 3)
                                                        .foregroundColor(.green)
                                                    VStack(alignment: .leading) {
                                                        AnnouncementView(chat: model.database.chat)
                                                        LineView(
                                                            post: post,
                                                            chat: model.database.chat
                                                        )
                                                    }
                                                }
                                                .id(post)
                                            } else if post.isFirstMessage {
                                                HStack(spacing: 0) {
                                                    Rectangle()
                                                        .frame(width: 3)
                                                        .foregroundColor(.yellow)
                                                    VStack(alignment: .leading) {
                                                        FirstMessageView(chat: model.database.chat)
                                                        LineView(
                                                            post: post,
                                                            chat: model.database.chat
                                                        )
                                                    }
                                                }
                                                .id(post)
                                            } else {
                                                LineView(
                                                    post: post,
                                                    chat: model.database.chat
                                                )
                                                .padding([.leading], 3)
                                                .id(post)
                                            }
                                        } else {
                                            Rectangle()
                                                .fill(.red)
                                                .frame(
                                                    width: metrics.size.width,
                                                    height: 1.5
                                                )
                                                .padding(2)
                                                .id(post)
                                        }
                                    }
                                }
                            }
                            .onChange(of: model.chatPosts) { _ in
                                if !model.chatPaused {
                                    reader.scrollTo(
                                        model.chatPosts.last,
                                        anchor: .bottom
                                    )
                                }
                            }
                            .frame(minHeight: metrics.size.height)
                            .onAppear {
                                if !model.chatPaused {
                                    reader.scrollTo(
                                        model.chatPosts.last,
                                        anchor: .bottom
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(width: fullMetrics.size.width * model.database.chat.width!,
                       height: fullMetrics.size.height * model.database.chat.height!)
            }
        }
    }
}
