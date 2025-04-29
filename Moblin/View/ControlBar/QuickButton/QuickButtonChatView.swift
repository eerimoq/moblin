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

struct ChildSizeReader<Content: View>: View {
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

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value _: inout CGSize, nextValue: () -> CGSize) {
        _ = nextValue()
    }
}

private var previousOffset = 0.0

private struct MessagesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: ChatProvider
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
            ChildSizeReader(size: $wholeSize) {
                ScrollView {
                    ChildSizeReader(size: $scrollViewSize) {
                        VStack {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(chat.posts) { post in
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
                                    if chat.paused, offset >= previousOffset {
                                        model.endOfQuickButtonChatReachedWhenPaused()
                                    }
                                } else if !chat.paused {
                                    if !chat.posts.isEmpty {
                                        model.pauseQuickButtonChat()
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
    @ObservedObject var chat: ChatProvider

    var body: some View {
        ZStack {
            MessagesView(chat: chat)
            if chat.paused {
                ChatInfo(
                    message: String(localized: "Chat paused: \(chat.pausedPostsCount) new messages")
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
            ChildSizeReader(size: $wholeSize) {
                ScrollView {
                    ChildSizeReader(size: $scrollViewSize) {
                        VStack {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(model.quickButtonChatAlertsPosts) { post in
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
                                                .rotationEffect(Angle(degrees: rotation))
                                                .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                            }
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
                                    if model.quickButtonChatAlertsPaused, offset >= previousOffset {
                                        model.endOfQuickButtonChatAlertsReachedWhenPaused()
                                    }
                                } else if !model.quickButtonChatAlertsPaused {
                                    if !model.quickButtonChatAlertsPosts.isEmpty {
                                        model.pauseQuickButtonChatAlerts()
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
            }
        }
    }
}

private struct ChatAlertsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            AlertsMessagesView()
            if model.quickButtonChatAlertsPaused {
                ChatInfo(
                    message: String(localized: "Chat paused: \(model.pausedQuickButtonChatAlertsPostsCount) new alerts")
                )
                .padding(2)
            }
            HypeTrainView()
        }
    }
}

private struct ControlAlertsButtonView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button(action: {
            model.showAllQuickButtonChatMessage.toggle()
        }, label: {
            Image(systemName: model
                .showAllQuickButtonChatMessage ? "megaphone" : "megaphone.fill")
                .font(.title)
                .padding(5)
        })
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
        .submitLabel(.send)
        .onSubmit {
            if !message.isEmpty {
                model.sendChatMessage(message: message)
            }
            message = ""
        }
        .padding(5)
        .foregroundColor(.white)
        ControlAlertsButtonView()
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
        ControlAlertsButtonView()
    }
}

struct QuickButtonChatView: View {
    @EnvironmentObject var model: Model
    @State var message: String = ""

    var body: some View {
        VStack {
            if model.showAllQuickButtonChatMessage {
                ChatView(chat: model.quickButtonChat)
            } else {
                ChatAlertsView()
            }
            HStack {
                if model.showAllQuickButtonChatMessage {
                    ControlView(message: $message)
                } else {
                    AlertsControlView()
                }
            }
            .frame(height: 50)
            .border(.gray)
            .padding([.leading, .trailing], 5)
        }
        .background(.black)
        .navigationTitle("Chat")
    }
}
