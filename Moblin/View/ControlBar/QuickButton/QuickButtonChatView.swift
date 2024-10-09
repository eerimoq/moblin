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
        if let color = post.userColor {
            return color.color()
        } else {
            return chat.usernameColor.color()
        }
    }

    var body: some View {
        let usernameColor = usernameColor()
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chat.timestampColorEnabled {
                Text("\(post.timestamp) ")
                    .foregroundColor(.gray)
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
                .bold()
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments, id: \.id) { segment in
                if let text = segment.text {
                    Text(text)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 25)
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(height: 25)
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
                                                VStack(alignment: .leading, spacing: 1) {
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
                .foregroundColor(.white)
                .rotationEffect(Angle(degrees: 180))
                .scaleEffect(x: -1.0, y: 1.0, anchor: .center)
                .coordinateSpace(name: spaceName)
            }
        }
    }
}

private struct HypeTrainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundColor(.clear)
                .background(.clear)
                .frame(height: 1)
            VStack {
                if let level = model.hypeTrainLevel {
                    HStack(spacing: 0) {
                        let train = HStack(spacing: 0) {
                            Image(systemName: "train.side.rear.car")
                            Image(systemName: "train.side.middle.car")
                            Image(systemName: "train.side.middle.car")
                            Image(systemName: "train.side.middle.car")
                            Image(systemName: "train.side.front.car")
                        }
                        if #available(iOS 18.0, *) {
                            train
                                .symbolEffect(
                                    .wiggle.forward.byLayer,
                                    options: .repeat(.periodic(delay: 2.0))
                                )
                        } else {
                            train
                        }
                        Spacer()
                        Text("LEVEL \(level)")
                        Button {
                            model.removeHypeTrain()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.footnote)
                                .frame(width: 25, height: 25)
                                .overlay(
                                    Circle()
                                        .stroke(.secondary)
                                )
                                .padding([.leading], 15)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(10)
                }
                if let progress = model.hypeTrainProgress, let goal = model.hypeTrainGoal {
                    ProgressView(value: Float(progress), total: Float(goal))
                        .accentColor(.white)
                        .scaleEffect(x: 1, y: 4, anchor: .center)
                        .padding([.top, .leading, .trailing], 10)
                        .padding([.bottom], 20)
                }
            }
            .background(RgbColor(red: 0x64, green: 0x41, blue: 0xA5).color())
            Spacer()
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
            HypeTrainView()
        }
    }
}

private struct AlertsMessagesView: View {
    @EnvironmentObject var model: Model
    private let spaceName = "scroll"
    @State var wholeSize: CGSize = .zero
    @State var scrollViewSize: CGSize = .zero

    private func shouldShowMessage(highlight: ChatHighlight) -> Bool {
        if highlight.kind == .firstMessage && !model.showFirstTimeChatterMessage {
            return false
        }
        if highlight.kind == .newFollower && !model.showNewFollowerMessage {
            return false
        }
        return true
    }

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
                                            if shouldShowMessage(highlight: highlight) {
                                                HStack(spacing: 0) {
                                                    Rectangle()
                                                        .frame(width: 3)
                                                        .foregroundColor(highlight.color)
                                                    VStack(alignment: .leading, spacing: 1) {
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
                                            }
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
                .foregroundColor(.white)
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
            HypeTrainView()
        }
    }
}

private struct ControlView: View {
    @EnvironmentObject var model: Model
    @Binding var message: String

    var body: some View {
        TextField(text: $message) {
            Text("Send message")
                .foregroundColor(.gray)
        }
        .padding(5)
        .foregroundColor(.white)
        Button(action: {
            model.sendChatMessage(message: message)
            message = ""
        }, label: {
            Image(systemName: "paperplane")
                .font(.title)
                .padding(5)
                .foregroundColor(message.isEmpty ? .gray : .accentColor)
        })
        .disabled(message.isEmpty)
        Button(action: {
            model.showAllInteractiveChatMessage.toggle()
        }, label: {
            Image(systemName: model
                .showAllInteractiveChatMessage ? "megaphone" : "megaphone.fill")
                .font(.title)
                .padding(5)
        })
    }
}

private struct AlertsControlView: View {
    @EnvironmentObject var model: Model
    @State var message: String = ""

    var body: some View {
        Button(action: {
            model.showFirstTimeChatterMessage.toggle()
            model.database.chat.showFirstTimeChatterMessage = model.showFirstTimeChatterMessage
        }, label: {
            Image(systemName: model
                .showFirstTimeChatterMessage ? "bubble.left.fill" : "bubble.left")
                .font(.title)
                .padding(5)
        })
        Button(action: {
            model.showNewFollowerMessage.toggle()
            model.database.chat.showNewFollowerMessage = model.showNewFollowerMessage
        }, label: {
            Image(systemName: model.showNewFollowerMessage ? "medal.fill" : "medal")
                .font(.title)
                .padding(5)
        })
        Spacer()
        Button(action: {
            model.showAllInteractiveChatMessage.toggle()
        }, label: {
            Image(systemName: model
                .showAllInteractiveChatMessage ? "megaphone" : "megaphone.fill")
                .font(.title)
                .padding(5)
        })
    }
}

struct QuickButtonChatView: View {
    @EnvironmentObject var model: Model
    @State var message: String = ""

    var body: some View {
        VStack {
            if model.showAllInteractiveChatMessage {
                ChatView()
            } else {
                ChatAlertsView()
            }
            HStack {
                if model.showAllInteractiveChatMessage {
                    ControlView(message: $message)
                } else {
                    AlertsControlView()
                }
            }
            .border(.gray)
            .padding([.leading, .trailing], 5)
        }
        .background(.black)
        .navigationTitle("Chat")
    }
}
