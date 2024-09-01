import Foundation
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

private struct HighlightMessageView: View {
    let image: String
    let name: String

    var body: some View {
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
        .padding([.leading], 5)
    }
}

private struct LineView: View {
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

    var body: some View {
        let timestampColor = chat.timestampColor.color()
        let usernameColor = usernameColor()
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
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments, id: \.id) { segment in
                if let text = segment.text {
                    Text(text)
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
        .padding([.leading], 5)
    }
}

private struct ChildSizeReader<Content: View>: View {
    // periphery:ignore
    @Binding var size: CGSize
    let content: () -> Content

    var body: some View {
        content()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(SizePreferenceKey.self) { preferences in
                self.size = preferences
            }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value _: inout CGSize, nextValue: () -> CGSize) {
        _ = nextValue()
    }
}

private var previousOffset = 0.0

private struct MessagesView: View {
    @EnvironmentObject var model: Model
    private let spaceName = "scroll"
    @State var wholeSize: CGSize = .zero
    @State var scrollViewSize: CGSize = .zero

    var body: some View {
        GeometryReader { metrics in
            ChildSizeReader(size: $wholeSize) {
                ScrollView {
                    ChildSizeReader(size: $scrollViewSize) {
                        VStack {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(model.interactiveChatPosts) { post in
                                    if post.user != nil {
                                        if let highlight = post.highlight {
                                            HStack(spacing: 0) {
                                                Rectangle()
                                                    .frame(width: 3)
                                                    .foregroundColor(highlight.color)
                                                VStack(alignment: .leading) {
                                                    HighlightMessageView(
                                                        image: highlight.image,
                                                        name: highlight.title
                                                    )
                                                    LineView(
                                                        post: post,
                                                        chat: model.database.chat
                                                    )
                                                }
                                            }
                                            .rotationEffect(Angle(degrees: 180))
                                            .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                                        } else {
                                            LineView(post: post, chat: model.database.chat)
                                                .padding([.leading], 3)
                                                .rotationEffect(Angle(degrees: 180))
                                                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                                        }
                                    } else {
                                        Rectangle()
                                            .fill(.red)
                                            .frame(width: metrics.size.width, height: 1.5)
                                            .padding(2)
                                            .rotationEffect(Angle(degrees: 180))
                                            .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
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
                                if offset >= scrollViewSize.height - wholeSize.height - 50 {
                                    if model.interactiveChatPaused, offset >= previousOffset {
                                        model.endOfInteractiveChatReachedWhenPaused()
                                    }
                                } else if !model.interactiveChatPaused {
                                    if !model.interactiveChatPosts.isEmpty {
                                        model.pauseInteractiveChat()
                                    }
                                }
                                previousOffset = offset
                            }
                        )
                        .frame(minHeight: metrics.size.height)
                    }
                }
                .rotationEffect(Angle(degrees: 180))
                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                .coordinateSpace(name: spaceName)
            }
        }
    }
}

private struct ChatView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            MessagesView()
            if model.interactiveChatPaused {
                ChatInfo(
                    message: String(
                        localized: "Chat paused: \(model.pausedInteractiveChatPostsCount) new messages"
                    )
                )
                .padding(2)
            }
        }
    }
}

private struct AlertsMessagesView: View {
    @EnvironmentObject var model: Model
    private let spaceName = "scroll"
    @State var wholeSize: CGSize = .zero
    @State var scrollViewSize: CGSize = .zero

    var body: some View {
        GeometryReader { metrics in
            ChildSizeReader(size: $wholeSize) {
                ScrollView {
                    ChildSizeReader(size: $scrollViewSize) {
                        VStack {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(model.interactiveChatAlertsPosts) { post in
                                    if post.user != nil {
                                        if let highlight = post.highlight {
                                            HStack(spacing: 0) {
                                                Rectangle()
                                                    .frame(width: 3)
                                                    .foregroundColor(highlight.color)
                                                VStack(alignment: .leading) {
                                                    HighlightMessageView(
                                                        image: highlight.image,
                                                        name: highlight.title
                                                    )
                                                    LineView(
                                                        post: post,
                                                        chat: model.database.chat
                                                    )
                                                }
                                            }
                                            .rotationEffect(Angle(degrees: 180))
                                            .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                                        } else {
                                            LineView(post: post, chat: model.database.chat)
                                                .padding([.leading], 3)
                                                .rotationEffect(Angle(degrees: 180))
                                                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                                        }
                                    } else {
                                        Rectangle()
                                            .fill(.red)
                                            .frame(width: metrics.size.width, height: 1.5)
                                            .padding(2)
                                            .rotationEffect(Angle(degrees: 180))
                                            .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
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
                                if offset >= scrollViewSize.height - wholeSize.height - 50 {
                                    if model.interactiveChatAlertsPaused, offset >= previousOffset {
                                        model.endOfInteractiveChatAlertsReachedWhenPaused()
                                    }
                                } else if !model.interactiveChatAlertsPaused {
                                    if !model.interactiveChatAlertsPosts.isEmpty {
                                        model.pauseInteractiveChatAlerts()
                                    }
                                }
                                previousOffset = offset
                            }
                        )
                        .frame(minHeight: metrics.size.height)
                    }
                }
                .rotationEffect(Angle(degrees: 180))
                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                .coordinateSpace(name: spaceName)
            }
        }
    }
}

private struct ChatAlertsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            AlertsMessagesView()
            if model.interactiveChatAlertsPaused {
                ChatInfo(
                    message: String(
                        localized: "Chat paused: \(model.pausedInteractiveChatAlertsPostsCount) new alerts"
                    )
                )
                .padding(2)
            }
        }
    }
}

struct QuickButtonChatView: View {
    @EnvironmentObject var model: Model
    var done: () -> Void
    @State var message: String = ""

    var body: some View {
        VStack {
            if model.showAllInteractiveChatMessage {
                ChatView()
            } else {
                ChatAlertsView()
            }
            HStack {
                TextField("Send message", text: $message)
                    .padding(5)
                Button(action: {
                    model.makeErrorToast(title: "Sending chat messages does not yet work")
                    message = ""
                }, label: {
                    Image(systemName: "paperplane")
                        .font(.title)
                        .padding(5)
                })
                .disabled(message.isEmpty)
                Button(action: {
                    model.showAllInteractiveChatMessage.toggle()
                }, label: {
                    Image(systemName: model.showAllInteractiveChatMessage ? "megaphone" : "megaphone.fill")
                        .font(.title)
                        .padding(5)
                })
            }
            .border(.secondary)
            .padding([.leading, .trailing], 5)
        }
        .navigationTitle("Chat")
        .toolbar {
            SettingsToolbar(quickDone: done)
        }
    }
}
