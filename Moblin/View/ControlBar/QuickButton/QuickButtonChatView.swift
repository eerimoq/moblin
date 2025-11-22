import Foundation
import SDWebImageSwiftUI
import SwiftUI
import WrappingHStack

private struct HighlightMessageView: View {
    @ObservedObject var postState: ChatPostState
    @ObservedObject var chat: SettingsChat
    let highlight: ChatHighlight

    private func frameHeightEmotes() -> CGFloat {
        return CGFloat(20 * 1.7) // Using default font size
    }

    private func imageOpacity() -> Double {
        return postState.deleted ? 0.25 : 1
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
                        .foregroundStyle(highlight.messageColor())
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 25)
                            .opacity(imageOpacity())
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(height: 25)
                        .opacity(imageOpacity())
                    }
                    Text(" ")
                }
            }
        }
        .foregroundStyle(highlight.messageColor())
        .padding([.leading], 5)
    }
}

private struct LineView: View {
    @ObservedObject var postState: ChatPostState
    let post: ChatPost
    @ObservedObject var chat: SettingsChat
    let platform: Bool
    @Binding var selectedPost: ChatPost?

    private func imageOpacity() -> Double {
        return postState.deleted ? 0.25 : 1
    }

    var body: some View {
        let usernameColor = post.userColor.color()
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chat.timestampColorEnabled {
                Text("\(post.timestamp) ")
                    .foregroundStyle(.gray)
            }
            if chat.platform, platform, let image = post.platform?.imageName() {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
                    .frame(height: CGFloat(chat.fontSize * 1.4))
                    .opacity(imageOpacity())
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
                    .opacity(imageOpacity())
                }
            }
            Text(post.displayName(nicknames: chat.nicknames, displayStyle: chat.displayStyle))
                .foregroundStyle(postState.deleted ? .gray : usernameColor)
                .strikethrough(postState.deleted)
                .lineLimit(1)
                .padding([.trailing], 0)
                .bold()
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments) { segment in
                if let text = segment.text {
                    Text(text)
                        .foregroundStyle(postState.deleted ? .gray : .white)
                        .strikethrough(postState.deleted)
                        .italic(post.isAction)
                }
                if let url = segment.url {
                    if chat.animatedEmotes {
                        WebImage(url: url)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 25)
                            .opacity(imageOpacity())
                    } else {
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(height: 25)
                        .opacity(imageOpacity())
                    }
                    Text(" ")
                }
            }
        }
        .padding([.leading], 5)
        .onTapGesture {
            selectedPost = post
        }
    }
}

private struct PostView: View {
    var model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
    @Binding var selectedPost: ChatPost?
    let post: ChatPost
    @ObservedObject var state: ChatPostState
    let rotation: Double
    let scaleX: Double
    let size: CGSize

    var body: some View {
        if post.user != nil {
            if !state.deleted || chatSettings.showDeletedMessages {
                if let highlight = post.highlight {
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: 3)
                            .foregroundStyle(highlight.barColor)
                        VStack(alignment: .leading, spacing: 1) {
                            HighlightMessageView(postState: post.state,
                                                 chat: chatSettings,
                                                 highlight: highlight)
                            LineView(postState: post.state,
                                     post: post,
                                     chat: chatSettings,
                                     platform: chat.moreThanOneStreamingPlatform,
                                     selectedPost: $selectedPost)
                        }
                    }
                    .rotationEffect(Angle(degrees: rotation))
                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                } else {
                    LineView(postState: post.state,
                             post: post,
                             chat: chatSettings,
                             platform: chat.moreThanOneStreamingPlatform,
                             selectedPost: $selectedPost)
                        .padding([.leading], 3)
                        .rotationEffect(Angle(degrees: rotation))
                        .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                }
            }
        } else {
            Rectangle()
                .fill(.red)
                .frame(width: size.width, height: 1.5)
                .padding(2)
                .rotationEffect(Angle(degrees: rotation))
                .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
        }
    }
}

private struct MessagesView: View {
    var model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
    @Binding var selectedPost: ChatPost?

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
                        PostView(model: model,
                                 chatSettings: chatSettings,
                                 chat: chat,
                                 selectedPost: $selectedPost,
                                 post: post,
                                 state: post.state,
                                 rotation: rotation,
                                 scaleX: scaleX,
                                 size: metrics.size)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(minHeight: metrics.size.height)
        }
        .foregroundStyle(.white)
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
                .foregroundStyle(.clear)
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
                    .foregroundStyle(.white)
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
    @Binding var selectedPost: ChatPost?

    var body: some View {
        ZStack {
            MessagesView(model: model,
                         chatSettings: model.database.chat,
                         chat: chat,
                         selectedPost: $selectedPost)
            if chat.paused {
                ChatInfo(message: String(localized: "Chat paused: \(chat.pausedPostsCount) new messages"))
                    .padding(2)
            }
            HypeTrainView(model: model, hypeTrain: model.hypeTrain)
        }
    }
}

private struct AlertsMessagesView: View {
    let model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
    @ObservedObject var quickButtonChat: QuickButtonChat
    @Binding var selectedPost: ChatPost?

    private func shouldShowMessage(highlight: ChatHighlight) -> Bool {
        if highlight.kind == .firstMessage && !quickButtonChat.showFirstTimeChatterMessage {
            return false
        }
        if highlight.kind == .newFollower && !quickButtonChat.showNewFollowerMessage {
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
                    ForEach(quickButtonChat.chatAlertsPosts) { post in
                        if post.user != nil {
                            if let highlight = post.highlight {
                                if shouldShowMessage(highlight: highlight) {
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .frame(width: 3)
                                            .foregroundStyle(highlight.barColor)
                                        VStack(alignment: .leading, spacing: 1) {
                                            HighlightMessageView(postState: post.state,
                                                                 chat: chatSettings,
                                                                 highlight: highlight)
                                            LineView(postState: post.state,
                                                     post: post,
                                                     chat: chatSettings,
                                                     platform: chat.moreThanOneStreamingPlatform,
                                                     selectedPost: $selectedPost)
                                        }
                                    }
                                    .rotationEffect(Angle(degrees: rotation))
                                    .scaleEffect(x: scaleX, y: 1.0, anchor: .center)
                                }
                            } else {
                                LineView(postState: post.state,
                                         post: post,
                                         chat: chatSettings,
                                         platform: chat.moreThanOneStreamingPlatform,
                                         selectedPost: $selectedPost)
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
        .foregroundStyle(.white)
        .rotationEffect(Angle(degrees: rotation))
        .scaleEffect(x: scaleX * chatSettings.isMirrored(), y: 1.0, anchor: .center)
    }
}

private struct ChatAlertsView: View {
    let model: Model
    @ObservedObject var quickButtonChat: QuickButtonChat
    @Binding var selectedPost: ChatPost?

    var body: some View {
        ZStack {
            AlertsMessagesView(model: model,
                               chatSettings: model.database.chat,
                               chat: model.quickButtonChat,
                               quickButtonChat: quickButtonChat,
                               selectedPost: $selectedPost)
            if quickButtonChat.chatAlertsPaused {
                ChatInfo(
                    message: String(
                        localized: "Chat paused: \(quickButtonChat.pausedChatAlertsPostsCount) new alerts"
                    )
                )
                .padding(2)
            }
            HypeTrainView(model: model, hypeTrain: model.hypeTrain)
        }
    }
}

private struct PredefinedMessagesToolbar: ToolbarContent {
    @Binding var showingPredefinedMessages: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingPredefinedMessages = false
            } label: {
                Image(systemName: "xmark")
            }
        }
    }
}

private struct TagButtonView: View {
    let tag: String
    @Binding var enabled: Bool

    var body: some View {
        if enabled {
            Button {
                enabled.toggle()
            } label: {
                Text(tag)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                enabled.toggle()
            } label: {
                Text(tag)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct PredefinedMessageView: View {
    let model: Model
    @ObservedObject var filter: SettingsChatPredefinedMessagesFilter
    @ObservedObject var predefinedMessage: SettingsChatPredefinedMessage
    @Binding var showingPredefinedMessages: Bool

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(title: String(localized: "Text"),
                                           value: predefinedMessage.text,
                                           onSubmit: {
                                               predefinedMessage.text = $0
                                           },
                                           placeholder: String(localized: "Hello chat!"))
                }
                Section {
                    HStack {
                        Spacer()
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagBlue, enabled: $predefinedMessage.blueTag)
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagGreen, enabled: $predefinedMessage.greenTag)
                        TagButtonView(
                            tag: SettingsChatPredefinedMessage.tagYellow,
                            enabled: $predefinedMessage.yellowTag
                        )
                        TagButtonView(
                            tag: SettingsChatPredefinedMessage.tagOrange,
                            enabled: $predefinedMessage.orangeTag
                        )
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagRed, enabled: $predefinedMessage.redTag)
                    }
                } header: {
                    Text("Tags")
                }
            }
            .navigationTitle("Predefined message")
        } label: {
            HStack {
                if filter.isEnabled() {
                    DraggableItemPrefixView()
                        .foregroundStyle(.gray)
                } else {
                    DraggableItemPrefixView()
                }
                Text(predefinedMessage.tagsString())
                Text(predefinedMessage.text)
                Spacer()
                Button {
                    model.sendChatMessage(message: predefinedMessage.text)
                    showingPredefinedMessages = false
                } label: {
                    Text("Send")
                }
                .buttonStyle(.borderless)
                .disabled(predefinedMessage.text.isEmpty)
            }
        }
    }
}

private struct PredefinedMessagesView: View {
    let model: Model
    @ObservedObject var chat: SettingsChat
    @ObservedObject var filter: SettingsChatPredefinedMessagesFilter
    @Binding var showingPredefinedMessages: Bool
    @State var messageToSend: UUID?

    private func filteredMessages() -> [SettingsChatPredefinedMessage] {
        guard filter.blueTag || filter.greenTag || filter.yellowTag || filter.orangeTag || filter.redTag else {
            return chat.predefinedMessages
        }
        var messages: [SettingsChatPredefinedMessage] = []
        for message in chat.predefinedMessages {
            var shouldAdd = true
            if filter.blueTag, !message.blueTag {
                shouldAdd = false
            }
            if filter.greenTag, !message.greenTag {
                shouldAdd = false
            }
            if filter.yellowTag, !message.yellowTag {
                shouldAdd = false
            }
            if filter.orangeTag, !message.orangeTag {
                shouldAdd = false
            }
            if filter.redTag, !message.redTag {
                shouldAdd = false
            }
            if shouldAdd {
                messages.append(message)
            }
        }
        return messages
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Filter")
                        Spacer()
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagBlue, enabled: $filter.blueTag)
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagGreen, enabled: $filter.greenTag)
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagYellow, enabled: $filter.yellowTag)
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagOrange, enabled: $filter.orangeTag)
                        TagButtonView(tag: SettingsChatPredefinedMessage.tagRed, enabled: $filter.redTag)
                    }
                }
                Section {
                    List {
                        let items = ForEach(filteredMessages()) { predefinedMessage in
                            PredefinedMessageView(model: model,
                                                  filter: filter,
                                                  predefinedMessage: predefinedMessage,
                                                  showingPredefinedMessages: $showingPredefinedMessages)
                        }
                        if filter.isEnabled() {
                            items
                        } else {
                            items
                                .onDelete {
                                    chat.predefinedMessages.remove(atOffsets: $0)
                                }
                                .onMove { froms, to in
                                    chat.predefinedMessages.move(fromOffsets: froms, toOffset: to)
                                }
                        }
                    }
                    Section {
                        TextButtonView("Create") {
                            chat.predefinedMessages.append(SettingsChatPredefinedMessage())
                        }
                    }
                } footer: {
                    if filter.isEnabled() {
                        Text("Cannot move or delete predefined messages when filtering.")
                    } else {
                        SwipeLeftToDeleteHelpView(kind: String(localized: "a predefined message"))
                    }
                }
            }
            .navigationTitle("Predefined messages")
            .toolbar {
                PredefinedMessagesToolbar(showingPredefinedMessages: $showingPredefinedMessages)
            }
        }
    }
}

private struct SendMessagesToView: View {
    let image: String
    let name: String
    @Binding var enabled: Bool

    var body: some View {
        Button {
            enabled.toggle()
        } label: {
            HStack {
                Image(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if enabled {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .font(.title2)
                }
            }
        }
    }
}

private struct PlatformIconView: View {
    let image: String

    var body: some View {
        Image(image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 25, height: 25)
    }
}

private struct SendMessagesToSelectorView: View {
    @ObservedObject var stream: SettingsStream
    @State var showingSelector = false

    private func isTwitchOnly() -> Bool {
        return stream.twitchSendMessagesTo && !stream.kickSendMessagesTo
    }

    private func isKickOnly() -> Bool {
        return stream.kickSendMessagesTo && !stream.twitchSendMessagesTo
    }

    var body: some View {
        Button {
            showingSelector = true
        } label: {
            if isTwitchOnly() {
                PlatformIconView(image: "TwitchLogo")
            } else if isKickOnly() {
                PlatformIconView(image: "KickLogo")
            } else {
                Image(systemName: "globe")
                    .font(.title)
                    .padding(5)
            }
        }
        .sheet(isPresented: $showingSelector) {
            NavigationView {
                Form {
                    Section {
                        SendMessagesToView(image: "TwitchLogo",
                                           name: String(localized: "Twitch"),
                                           enabled: $stream.twitchSendMessagesTo)
                        SendMessagesToView(image: "KickLogo",
                                           name: String(localized: "Kick"),
                                           enabled: $stream.kickSendMessagesTo)
                    }
                }
                .navigationTitle("Send messages to")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingSelector = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
    }
}

private struct ControlMessagesButtonView: View {
    let model: Model
    @State var showingPredefinedMessages = false

    var body: some View {
        Button {
            showingPredefinedMessages = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.title)
                .padding(5)
        }
        .sheet(isPresented: $showingPredefinedMessages) {
            PredefinedMessagesView(model: model,
                                   chat: model.database.chat,
                                   filter: model.database.chat.predefinedMessagesFilter,
                                   showingPredefinedMessages: $showingPredefinedMessages)
        }
    }
}

private struct ControlAlertsButtonView: View {
    @ObservedObject var quickButtonChat: QuickButtonChat

    var body: some View {
        Button {
            quickButtonChat.showAllChatMessages.toggle()
        } label: {
            Image(systemName: quickButtonChat.showAllChatMessages ? "megaphone" : "megaphone.fill")
                .font(.title)
                .padding(5)
        }
    }
}

private struct ControlView: View {
    let model: Model
    @Binding var message: String

    var body: some View {
        TextField(text: $message) {
            Text("Send message")
                .foregroundStyle(.gray)
        }
        .submitLabel(.send)
        .onSubmit {
            if !message.isEmpty {
                model.sendChatMessage(message: message)
            }
            message = ""
        }
        .padding(5)
        .foregroundStyle(.white)
        SendMessagesToSelectorView(stream: model.stream)
        ControlMessagesButtonView(model: model)
        ControlAlertsButtonView(quickButtonChat: model.quickButtonChatState)
    }
}

private struct AlertsControlView: View {
    let model: Model
    @ObservedObject var quickButtonChat: QuickButtonChat
    @State var message: String = ""

    var body: some View {
        Button {
            quickButtonChat.showFirstTimeChatterMessage.toggle()
            model.database.chat.showFirstTimeChatterMessage = quickButtonChat.showFirstTimeChatterMessage
        } label: {
            Image(systemName: quickButtonChat.showFirstTimeChatterMessage ? "bubble.left.fill" : "bubble.left")
                .font(.title)
                .padding(5)
        }
        Button {
            quickButtonChat.showNewFollowerMessage.toggle()
            model.database.chat.showNewFollowerMessage = quickButtonChat.showNewFollowerMessage
        } label: {
            Image(systemName: quickButtonChat.showNewFollowerMessage ? "medal.fill" : "medal")
                .font(.title)
                .padding(5)
        }
        Spacer()
        ControlAlertsButtonView(quickButtonChat: quickButtonChat)
    }
}

private struct ActionButtonView: View {
    var image: String
    var text: String
    var foreground: Color = .blue
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack {
                Image(systemName: image)
                    .foregroundStyle(foreground)
                    .font(.title)
                Text(text)
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct ActionButtonsView: View {
    let model: Model
    @Binding var selectedPost: ChatPost?
    @State var isPresentingBanConfirm = false
    @State var isPresentingTimeoutConfirm = false
    @State var isPresentingDeleteConfirm = false
    @State var isPresentingNicknameDialog = false
    @State var nicknameText = ""

    private func dismiss() {
        selectedPost = nil
    }

    private var chat: SettingsChat {
        return model.database.chat
    }

    private func banButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "nosign", text: String(localized: "Ban"), foreground: .red) {
            isPresentingBanConfirm = true
        }
        .confirmationDialog("", isPresented: $isPresentingBanConfirm) {
            Button("Ban", role: .destructive) {
                model.banUser(post: selectedPost)
                dismiss()
            }
        }
    }

    private func timeoutButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "timer", text: String(localized: "Timeout")) {
            isPresentingTimeoutConfirm = true
        }
        .confirmationDialog("", isPresented: $isPresentingTimeoutConfirm) {
            Button("5 minutes timeout", role: .destructive) {
                model.timeoutUser(post: selectedPost, duration: 5 * 60)
                dismiss()
            }
            Button("1 hour timeout", role: .destructive) {
                model.timeoutUser(post: selectedPost, duration: 3600)
                dismiss()
            }
            Button("24 hours timeout", role: .destructive) {
                model.timeoutUser(post: selectedPost, duration: 24 * 3600)
                dismiss()
            }
        }
    }

    private func deleteButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "trash", text: String(localized: "Delete")) {
            isPresentingDeleteConfirm = true
        }
        .confirmationDialog("", isPresented: $isPresentingDeleteConfirm) {
            Button("Delete message", role: .destructive) {
                model.deleteMessage(post: selectedPost)
                dismiss()
            }
        }
    }

    private func copyButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "document.on.document", text: String(localized: "Copy")) {
            model.copyMessage(post: selectedPost)
            dismiss()
        }
    }

    private func nicknameButton(selectedPost: ChatPost) -> some View {
        ActionButtonView(image: "person.badge.plus", text: String(localized: "Nickname")) {
            if let user = selectedPost.user {
                nicknameText = chat.nicknames.getNickname(user: user) ?? ""
            } else {
                nicknameText = ""
            }
            isPresentingNicknameDialog = true
        }
        .alert("Nickname for \(selectedPost.user ?? "")", isPresented: $isPresentingNicknameDialog) {
            TextField("Nickname", text: $nicknameText)
            Button("Save") {
                saveNickname(selectedPost: selectedPost)
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        }
    }

    private func saveNickname(selectedPost: ChatPost) {
        guard let user = selectedPost.user else {
            return
        }
        let nickname = nicknameText.trimmingCharacters(in: .whitespaces)
        if nickname.isEmpty {
            chat.nicknames.nicknames.removeAll(where: { $0.user == user })
        } else if let existingNickname = chat.nicknames.nicknames.first(where: { $0.user == user }) {
            existingNickname.nickname = nickname
        } else {
            let item = SettingsChatNickname()
            item.user = user
            item.nickname = nickname
            chat.nicknames.nicknames.append(item)
        }
        model.reloadChatMessages()
    }

    var body: some View {
        if let selectedPost {
            VStack {
                Spacer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.selectedPost = nil
                    }
                VStack(alignment: .leading) {
                    ScrollView {
                        LineView(postState: selectedPost.state,
                                 post: selectedPost,
                                 chat: model.database.chat,
                                 platform: model.chat.moreThanOneStreamingPlatform,
                                 selectedPost: $selectedPost)
                            .foregroundStyle(.white)
                    }
                    .frame(height: 100)
                    .padding([.top, .bottom], 5)
                    HStack {
                        Spacer()
                        banButton(selectedPost: selectedPost)
                        Spacer()
                        timeoutButton(selectedPost: selectedPost)
                        Spacer()
                        deleteButton(selectedPost: selectedPost)
                        Spacer()
                        copyButton(selectedPost: selectedPost)
                        Spacer()
                        nicknameButton(selectedPost: selectedPost)
                        Spacer()
                    }
                    .padding([.bottom], 5)
                }
                .border(.gray)
                .padding([.leading, .trailing], 5)
                .background(.black)
            }
        }
    }
}

struct QuickButtonChatView: View {
    let model: Model
    @ObservedObject var quickButtonChat: QuickButtonChat
    @State var message: String = ""
    @State var selectedPost: ChatPost?

    var body: some View {
        ZStack {
            VStack {
                if quickButtonChat.showAllChatMessages {
                    ChatView(model: model, chat: model.quickButtonChat, selectedPost: $selectedPost)
                } else {
                    ChatAlertsView(model: model, quickButtonChat: quickButtonChat, selectedPost: $selectedPost)
                }
                HStack {
                    if quickButtonChat.showAllChatMessages {
                        ControlView(model: model, message: $message)
                    } else {
                        AlertsControlView(model: model, quickButtonChat: quickButtonChat)
                    }
                }
                .frame(height: 50)
                .border(.gray)
                .padding([.leading, .trailing], 5)
            }
            ActionButtonsView(model: model, selectedPost: $selectedPost)
        }
        .background(.black)
        .navigationTitle("Chat")
    }
}
