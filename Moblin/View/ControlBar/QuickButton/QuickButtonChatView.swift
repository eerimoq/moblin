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
        return post.userColor.color()
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
            if chat.badges {
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

private struct MessagesView: View {
    var model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider

    var body: some View {
        let rotation = chatSettings.getRotation()
        let scaleX = chatSettings.getScaleX()
        GeometryReader { metrics in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    Color.clear
                        .onAppear {
                            model.endOfQuickButtonChatReachedWhenPaused()
                        }
                        .onDisappear {
                            model.pauseQuickButtonChat()
                        }
                        .frame(height: 1)
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
                                        LineView(post: post, chat: chatSettings)
                                    }
                                }
                                .rotationEffect(Angle(degrees: rotation))
                                .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                            } else {
                                LineView(post: post, chat: chatSettings)
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
                    Spacer(minLength: 0)
                }
            }
            .frame(minHeight: metrics.size.height)
        }
        .foregroundColor(.white)
        .rotationEffect(Angle(degrees: rotation))
        .scaleEffect(x: scaleX * chatSettings.isMirrored(), y: 1.0, anchor: .center)
    }
}

private struct HypeTrainView: View {
    var model: Model
    @ObservedObject var hypeTrain: HypeTrain

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .foregroundColor(.clear)
                .background(.clear)
                .frame(height: 1)
            VStack {
                if let level = hypeTrain.level {
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
                if let progress = hypeTrain.progress, let goal = hypeTrain.goal {
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
    var model: Model
    @ObservedObject var chat: ChatProvider

    var body: some View {
        ZStack {
            MessagesView(model: model, chatSettings: model.database.chat, chat: chat)
            if chat.paused {
                ChatInfo(
                    message: String(localized: "Chat paused: \(chat.pausedPostsCount) new messages")
                )
                .padding(2)
            }
            HypeTrainView(model: model, hypeTrain: model.hypeTrain)
        }
    }
}

private struct AlertsMessagesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chatSettings: SettingsChat

    private func shouldShowMessage(highlight: ChatHighlight) -> Bool {
        if highlight.kind == .firstMessage && !model.showFirstTimeChatterMessage {
            return false
        }
        if highlight.kind == .newFollower && !model.showNewFollowerMessage {
            return false
        }
        if highlight.kind == .reply {
            return false
        }
        return true
    }

    var body: some View {
        let rotation = chatSettings.getRotation()
        let scaleX = chatSettings.getScaleX()
        GeometryReader { metrics in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    Color.clear
                        .onAppear {
                            model.endOfQuickButtonChatAlertsReachedWhenPaused()
                        }
                        .onDisappear {
                            model.pauseQuickButtonChatAlerts()
                        }
                        .frame(height: 1)
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
                                            LineView(post: post, chat: chatSettings)
                                        }
                                    }
                                    .rotationEffect(Angle(degrees: rotation))
                                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                }
                            } else {
                                LineView(post: post, chat: chatSettings)
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
                    Spacer(minLength: 0)
                }
            }
            .frame(minHeight: metrics.size.height)
        }
        .foregroundColor(.white)
        .rotationEffect(Angle(degrees: rotation))
        .scaleEffect(x: scaleX * chatSettings.isMirrored(), y: 1.0, anchor: .center)
    }
}

private struct ChatAlertsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            AlertsMessagesView(chatSettings: model.database.chat)
            if model.quickButtonChatAlertsPaused {
                ChatInfo(
                    message: String(localized: "Chat paused: \(model.pausedQuickButtonChatAlertsPostsCount) new alerts")
                )
                .padding(2)
            }
            HypeTrainView(model: model, hypeTrain: model.hypeTrain)
        }
    }
}

private struct ControlAlertsButtonView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.showAllQuickButtonChatMessage.toggle()
        } label: {
            Image(systemName: model
                .showAllQuickButtonChatMessage ? "megaphone" : "megaphone.fill")
                .font(.title)
                .padding(5)
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
        Button {
            model.showFirstTimeChatterMessage.toggle()
            model.database.chat.showFirstTimeChatterMessage = model.showFirstTimeChatterMessage
        } label: {
            Image(systemName: model
                .showFirstTimeChatterMessage ? "bubble.left.fill" : "bubble.left")
                .font(.title)
                .padding(5)
        }
        Button {
            model.showNewFollowerMessage.toggle()
            model.database.chat.showNewFollowerMessage = model.showNewFollowerMessage
        } label: {
            Image(systemName: model.showNewFollowerMessage ? "medal.fill" : "medal")
                .font(.title)
                .padding(5)
        }
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
                ChatView(model: model, chat: model.quickButtonChat)
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
