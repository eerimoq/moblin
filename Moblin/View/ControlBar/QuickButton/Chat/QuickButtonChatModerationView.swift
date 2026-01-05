import SwiftUI

private enum ExecutorState {
    case idle
    case inProgress
    case success
    case authError
    case error
}

private class Executor: ObservableObject {
    @Published var state: ExecutorState = .idle

    func startProgress() {
        state = .inProgress
    }

    func completed(result: OperationResult) {
        switch result {
        case .success:
            state = .success
        case .authError:
            state = .authError
        case .error:
            state = .error
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.state = .idle
        }
    }
}

private struct ExecutorView<Content: View>: View {
    @EnvironmentObject var model: Model
    @ObservedObject var executor: Executor
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            switch executor.state {
            case .idle:
                content()
            case .inProgress:
                ProgressView()
            case .success:
                Text("Success")
                    .foregroundStyle(.green)
            case .authError:
                Text("Not logged in")
                    .foregroundStyle(.red)
            case .error:
                Text("Failed")
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: executor.state) { _ in
            if executor.state == .authError {
                model.showModerationAuth = true
                model.twitchLogin(stream: model.stream)
            }
        }
    }
}

private struct ToggleActionView: View {
    let text: LocalizedStringKey
    let image: String
    let action: (Bool, @escaping (OperationResult) -> Void) -> Void
    @StateObject private var executor = Executor()

    private func button(text: LocalizedStringKey, on: Bool) -> some View {
        BorderlessButtonView(text: text) {
            executor.startProgress()
            action(on, executor.completed)
        }
    }

    var body: some View {
        HStack {
            IconAndTextLocalizedView(image: image, text: text)
            Spacer()
            ExecutorView(executor: executor) {
                button(text: "On", on: true)
                    .padding([.trailing], 15)
                button(text: "Off", on: false)
            }
        }
    }
}

private struct DurationActionView: View {
    let text: LocalizedStringKey
    let image: String
    let durations: [Int]
    let action: (Int?, @escaping (OperationResult) -> Void) -> Void
    @StateObject private var executor = Executor()
    @State private var duration: Int?

    var body: some View {
        HStack {
            IconAndTextLocalizedView(image: image, text: text)
            Spacer()
            ExecutorView(executor: executor) {
                Picker("", selection: $duration) {
                    Text("Off")
                        .tag(nil as Int?)
                    ForEach(durations, id: \.self) {
                        Text(formatFullDuration(seconds: $0))
                            .tag($0 as Int?)
                    }
                }
                .padding([.trailing], 15)
                BorderlessButtonView(text: "Send") {
                    executor.startProgress()
                    action(duration, executor.completed)
                }
            }
        }
    }
}

private enum ModActionType: CaseIterable {
    case ban
    case timeout
    case unban
    case mod
    case unmod
    case vip
    case unvip

    func title() -> LocalizedStringKey {
        switch self {
        case .ban:
            return "Ban"
        case .timeout:
            return "Timeout"
        case .unban:
            return "Unban"
        case .mod:
            return "Mod"
        case .unmod:
            return "Unmod"
        case .vip:
            return "VIP"
        case .unvip:
            return "UnVIP"
        }
    }

    func image() -> String {
        switch self {
        case .ban:
            return "hand.raised"
        case .timeout:
            return "clock"
        case .unban:
            return "checkmark.circle"
        case .mod:
            return "shield"
        case .unmod:
            return "shield.slash"
        case .vip:
            return "crown"
        case .unvip:
            return "crown"
        }
    }
}

private struct UserModerationItemView: View {
    let model: Model
    let action: ModActionType
    let platform: Platform
    @State private var username = ""
    @State private var reason = ""
    @State private var timeoutDuration = 60
    @StateObject var executor = Executor()
    private let timeoutPresets = [60, 300, 600, 1800, 3600, 21600, 86400, 604_800]

    private func canExecute() -> Bool {
        return !username.trim().isEmpty
    }

    private func executeAction(onComplete: @escaping (OperationResult) -> Void) {
        let user = username.trim()
        let banReason = reason.trim()
        switch platform {
        case .kick:
            executeKickAction(user: user, banReason: banReason, onComplete: onComplete)
        case .twitch:
            executeTwitchAction(user: user, banReason: banReason, onComplete: onComplete)
        default:
            break
        }
    }

    private func executeKickAction(user: String,
                                   banReason: String,
                                   onComplete: @escaping (OperationResult) -> Void)
    {
        switch action {
        case .ban:
            model.banKickUser(user: user,
                              duration: nil,
                              reason: banReason.isEmpty ? nil : banReason,
                              onComplete: onComplete)
        case .timeout:
            model.banKickUser(user: user, duration: timeoutDuration, onComplete: onComplete)
        case .unban:
            model.unbanKickUser(user: user, onComplete: onComplete)
        case .mod:
            model.modKickUser(user: user, onComplete: onComplete)
        case .unmod:
            model.unmodKickUser(user: user, onComplete: onComplete)
        case .vip:
            model.vipKickUser(user: user, onComplete: onComplete)
        case .unvip:
            model.unvipKickUser(user: user, onComplete: onComplete)
        }
    }

    private func executeTwitchAction(user: String,
                                     banReason: String,
                                     onComplete: @escaping (OperationResult) -> Void)
    {
        switch action {
        case .ban:
            model.banTwitchUser(
                user: user,
                duration: nil,
                reason: banReason.isEmpty ? nil : banReason,
                onComplete: onComplete
            )
        case .timeout:
            model.banTwitchUser(user: user, duration: timeoutDuration, reason: nil, onComplete: onComplete)
        case .unban:
            model.unbanTwitchUser(user: user, onComplete: onComplete)
        case .mod:
            model.modTwitchUser(user: user, onComplete: onComplete)
        case .unmod:
            model.unmodTwitchUser(user: user, onComplete: onComplete)
        case .vip:
            model.vipTwitchUser(user: user, onComplete: onComplete)
        case .unvip:
            model.unvipTwitchUser(user: user, onComplete: onComplete)
        }
    }

    var body: some View {
        NavigationLinkView(text: action.title(), image: action.image()) {
            Section {
                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } header: {
                Text("Username")
            }
            if action == .timeout {
                Section {
                    Picker("Duration", selection: $timeoutDuration) {
                        ForEach(timeoutPresets, id: \.self) {
                            Text(formatFullDuration(seconds: $0))
                        }
                    }
                }
            }
            if action == .ban {
                Section {
                    TextField("Reason", text: $reason)
                } header: {
                    Text("Reason")
                }
            }
            Section {
                HCenter {
                    ExecutorView(executor: executor) {
                        TextButtonView("Send") {
                            executor.startProgress()
                            executeAction(onComplete: executor.completed)
                        }
                        .disabled(!canExecute())
                    }
                }
            }
        }
    }
}

private struct PollOption: Identifiable {
    let id: UUID = .init()
    var text: String = ""
}

private struct CreatePollView: View {
    let model: Model
    @State private var title: String = ""
    @State private var options = [PollOption(), PollOption()]
    @State private var duration: Int = 30
    @State private var resultDisplayDuration: Int = 15
    @StateObject private var executor = Executor()

    private func canExecute() -> Bool {
        let trimmedTitle = title.trim()
        let filledOptions = options.filter { !$0.text.trim().isEmpty }
        return !trimmedTitle.isEmpty && filledOptions.count >= 2
    }

    var body: some View {
        NavigationLinkView(text: "Create poll", image: "chart.bar") {
            Section("Title") {
                TextField("Title", text: $title)
            }
            Section {
                ForEach($options) { $option in
                    TextField("Option", text: $option.text)
                        .deleteDisabled(options.count <= 2)
                }
                .onDelete { offsets in
                    options.remove(atOffsets: offsets)
                }
                if options.count < 6 {
                    AddButtonView {
                        options.append(PollOption())
                    }
                }
            } header: {
                Text("Options")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "an option"))
            }
            Section {
                Picker("Duration", selection: $duration) {
                    ForEach([30, 120, 180, 240, 300], id: \.self) {
                        Text(formatFullDuration(seconds: $0))
                    }
                }
            }
            Section {
                Picker("Result display duration", selection: $resultDisplayDuration) {
                    ForEach([15, 30, 120, 180, 240, 300], id: \.self) {
                        Text(formatFullDuration(seconds: $0))
                    }
                }
            }
            Section {
                HCenter {
                    ExecutorView(executor: executor) {
                        CreateButtonView {
                            executor.startProgress()
                            model.createKickPoll(
                                title: title.trim(),
                                options: options.map { $0.text.trim() }.filter { !$0.isEmpty },
                                duration: duration,
                                resultDisplayDuration: resultDisplayDuration,
                                onComplete: executor.completed
                            )
                        }
                        .disabled(!canExecute())
                    }
                }
            }
        }
    }
}

private struct DeletePollView: View {
    let model: Model
    @StateObject private var executor = Executor()

    var body: some View {
        HStack {
            IconAndTextLocalizedView(image: "chart.bar", text: "Delete poll")
            Spacer()
            ExecutorView(executor: executor) {
                BorderlessButtonView(text: "Send") {
                    executor.startProgress()
                    model.deleteKickPoll(onComplete: executor.completed)
                }
            }
        }
    }
}

private struct CreatePredictionView: View {
    let model: Model
    @State private var title = ""
    @State private var outcome1 = ""
    @State private var outcome2 = ""
    @State private var duration = 300
    @StateObject private var executor = Executor()

    private func canExecute() -> Bool {
        return !title.trim().isEmpty && !outcome1.trim().isEmpty && !outcome2.trim().isEmpty
    }

    var body: some View {
        NavigationLinkView(text: "Create prediction", image: "sparkles") {
            Section("Title") {
                TextField("Title", text: $title)
            }
            Section("Outcomes") {
                TextField("Outcome", text: $outcome1)
                TextField("Outcome", text: $outcome2)
            }
            Section {
                Picker("Duration", selection: $duration) {
                    ForEach([60, 300, 600, 1800], id: \.self) {
                        Text(formatFullDuration(seconds: $0))
                    }
                }
            }
            Section {
                HCenter {
                    ExecutorView(executor: executor) {
                        CreateButtonView {
                            executor.startProgress()
                            model.createKickPrediction(title: title.trim(),
                                                       outcomes: [outcome1.trim(), outcome2.trim()],
                                                       duration: duration,
                                                       onComplete: executor.completed)
                        }
                        .disabled(!canExecute())
                    }
                }
            }
        }
    }
}

private struct StartTwitchRaidChannelView: View {
    let model: Model
    @Binding var channel: TwitchApiChannel
    @StateObject private var executor = Executor()

    var body: some View {
        HStack {
            if let url = URL(string: channel.thumbnail_url) {
                CacheAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image("AppIconNoBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .frame(width: 60)
                .clipShape(Circle())
            }
            VStack(alignment: .leading) {
                Text(channel.display_name)
                Text(channel.game_name)
                    .font(.caption)
                Text(channel.title)
                    .font(.caption)
            }
            Spacer()
            ExecutorView(executor: executor) {
                BorderlessButtonView(text: "Raid") {
                    executor.startProgress()
                    model.startRaidTwitchChannel(channelId: channel.id, onComplete: executor.completed)
                }
            }
        }
    }
}

private struct StartTwitchRaidView: View {
    let model: Model
    @State private var searchText: String = ""
    @State private var channels: [TwitchApiChannel] = []

    var body: some View {
        NavigationLinkView(text: "Raid channel", image: "play.tv") {
            Section {
                TextField("Search", text: $searchText)
                    .autocorrectionDisabled(true)
                    .onChange(of: searchText) { _ in
                        guard !searchText.isEmpty else {
                            return
                        }
                        model.searchTwitchChannels(stream: model.stream, filter: searchText) { channels in
                            DispatchQueue.main.async {
                                self.channels = channels ?? []
                            }
                        }
                    }
            }
            Section {
                ForEach($channels) { channel in
                    StartTwitchRaidChannelView(model: model, channel: channel)
                }
            }
        }
    }
}

private struct KickHostChannelView: View {
    let model: Model
    @State private var username: String = ""
    @State private var channels: [KickFollowedChannel] = []
    @State private var cursor: Int?
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var searchedChannel: KickChannel?
    @State private var isSearching = false
    @State private var searchCompleted = false

    private var onlineChannels: [KickFollowedChannel] {
        channels.filter { $0.is_live }
    }

    private func loadMore() {
        guard !isLoading else { return }
        isLoading = true
        getKickFollowedChannels(
            accessToken: model.stream.kickAccessToken,
            cursor: cursor
        ) { response in
            isLoading = false
            hasLoadedOnce = true
            if let response {
                channels.append(contentsOf: response.channels)
                cursor = response.nextCursor
            }
        }
    }

    private func searchChannel() {
        let trimmed = username.trim()
        guard !trimmed.isEmpty else {
            searchedChannel = nil
            searchCompleted = false
            return
        }
        guard !isSearching else { return }
        isSearching = true
        searchCompleted = false
        getKickChannelInfo(channelName: trimmed) { channel in
            searchedChannel = channel
            isSearching = false
            searchCompleted = true
        }
    }

    var body: some View {
        NavigationLinkView(text: "Host channel", image: "play.tv") {
            Section {
                HStack {
                    TextField("Search", text: $username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onSubmit {
                            searchChannel()
                        }
                        .onChange(of: username) { _ in
                            searchCompleted = false
                            searchedChannel = nil
                        }
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                if searchCompleted {
                    if let channel = searchedChannel {
                        KickSearchedChannelRowView(
                            channel: channel,
                            action: model.hostKickChannel
                        )
                    } else if !username.trim().isEmpty {
                        Text("Channel not found")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            if !hasLoadedOnce && isLoading {
                Section {
                    HCenter {
                        ProgressView()
                    }
                } header: {
                    Text("Online followed channels")
                }
            } else if !onlineChannels.isEmpty || cursor != nil {
                Section {
                    ForEach(onlineChannels) { channel in
                        KickFollowedChannelRowView(
                            channel: channel,
                            action: model.hostKickChannel
                        )
                    }
                    if cursor != nil {
                        HCenter {
                            if isLoading {
                                ProgressView()
                            } else {
                                Button("Load more") {
                                    loadMore()
                                }
                            }
                        }
                    }
                } header: {
                    Text("Online followed channels")
                }
            }
        }
        .onAppear {
            if !hasLoadedOnce {
                loadMore()
            }
        }
    }
}

private struct KickProfilePictureView: View {
    let url: String?

    var body: some View {
        if let profilePic = url, let imageUrl = URL(string: profilePic) {
            AsyncImage(url: imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
        }
    }
}

private struct KickFollowedChannelRowView: View {
    let channel: KickFollowedChannel
    let action: (String, @escaping (OperationResult) -> Void) -> Void
    @StateObject private var executor = Executor()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            KickProfilePictureView(url: channel.profile_picture)
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.user_username)
                if let title = channel.session_title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let category = channel.category_name {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let viewers = channel.viewer_count {
                HStack(spacing: 2) {
                    Image(systemName: "eye")
                    Text(countFormatter.format(viewers))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ExecutorView(executor: executor) {
                BorderlessButtonView(text: "Host") {
                    executor.startProgress()
                    action(channel.channel_slug) { result in
                        executor.completed(result: result)
                    }
                }
            }
        }
    }
}

private struct KickSearchedChannelRowView: View {
    let channel: KickChannel
    let action: (String, @escaping (OperationResult) -> Void) -> Void
    @StateObject private var executor = Executor()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                KickProfilePictureView(url: channel.user?.profile_pic)
                Circle()
                    .fill(channel.livestream != nil ? .green : .gray)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.slug)
                if let livestream = channel.livestream {
                    if let title = livestream.session_title, !title.isEmpty {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let category = livestream.categories?.first?.name {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let livestream = channel.livestream {
                HStack(spacing: 2) {
                    Image(systemName: "eye")
                    Text(countFormatter.format(livestream.viewers))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ExecutorView(executor: executor) {
                    BorderlessButtonView(text: "Host") {
                        executor.startProgress()
                        action(channel.slug) { result in
                            executor.completed(result: result)
                        }
                    }
                }
            }
        }
    }
}

private struct RunCommercialView: View {
    let model: Model
    @State private var duration = 30
    @StateObject private var executor = Executor()

    var body: some View {
        NavigationLinkView(text: "Run commercial", image: "cup.and.saucer") {
            Section {
                Picker("Duration", selection: $duration) {
                    ForEach([30, 60, 90, 120, 180], id: \.self) {
                        Text(formatFullDuration(seconds: $0))
                    }
                }
            } header: {
                Text("Duration")
            }
            Section {
                HCenter {
                    ExecutorView(executor: executor) {
                        TextButtonView("Run commercial") {
                            executor.startProgress()
                            model.startAds(seconds: duration, onComplete: executor.completed)
                        }
                    }
                }
            }
        }
    }
}

private enum AnnouncementColor: String, CaseIterable {
    case primary
    case blue
    case green
    case orange
    case purple

    func toString() -> String {
        switch self {
        case .primary:
            return String(localized: "Primary")
        case .blue:
            return "🔵"
        case .green:
            return "🟢"
        case .orange:
            return "🟠"
        case .purple:
            return "🟣"
        }
    }
}

private struct SendAnnouncementView: View {
    let model: Model
    @State private var message = ""
    @State private var color: AnnouncementColor = .primary
    @StateObject private var executor = Executor()

    private func canSend() -> Bool {
        return !message.trim().isEmpty
    }

    var body: some View {
        NavigationLinkView(text: "Send announcement", image: "megaphone") {
            Section {
                TextField("Message", text: $message)
            } header: {
                Text("Message")
            }
            Section {
                Picker("Color", selection: $color) {
                    ForEach(AnnouncementColor.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
            }
            Section {
                HCenter {
                    ExecutorView(executor: executor) {
                        TextButtonView("Send") {
                            executor.startProgress()
                            model.sendTwitchAnnouncement(message: message.trim(),
                                                         color: color.rawValue,
                                                         onComplete: executor.completed)
                        }
                        .disabled(!canSend())
                    }
                }
            }
        }
    }
}

private struct SlowModeView: View {
    let durations: [Int]
    let action: (Int?, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        DurationActionView(text: "Slow mode", image: "tortoise", durations: durations, action: action)
    }
}

private struct FollowersOnlyView: View {
    let durations: [Int]
    let action: (Int?, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        DurationActionView(text: "Followers only", image: "person.2", durations: durations, action: action)
    }
}

private struct SubscribersOnlyView: View {
    let action: (Bool, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: "Subscribers only", image: "star", action: action)
    }
}

private struct EmotesOnlyView: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: (Bool, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: "Emotes only",
                         image: colorScheme == .light ? "face.smiling" : "face.smiling.inverse",
                         action: action)
    }
}

private struct NavigationLinkView<Content: View>: View {
    let text: LocalizedStringKey
    let image: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationLink {
            Form {
                content()
            }
            .navigationTitle(text)
        } label: {
            IconAndTextLocalizedView(image: image, text: text)
        }
    }
}

private struct UserModerationView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationLinkView(text: "User moderation", image: "person", content: content)
    }
}

private struct ChatModesView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationLinkView(text: "Chat modes", image: "bubble.left", content: content)
    }
}

private struct ChannelManagementView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationLinkView(text: "Channel management", image: "gearshape", content: content)
    }
}

private struct TwitchUserModerationView: View {
    let model: Model

    var body: some View {
        UserModerationView {
            ForEach(ModActionType.allCases, id: \.self) {
                UserModerationItemView(model: model, action: $0, platform: .twitch)
            }
        }
    }
}

private struct TwitchChatModesView: View {
    let model: Model

    private func slowModeAction(duration: Int?, onComplete: @escaping (OperationResult) -> Void) {
        model.setTwitchSlowMode(enabled: duration != nil, duration: duration, onComplete: onComplete)
    }

    private func followersOnlyAction(duration: Int?, onComplete: @escaping (OperationResult) -> Void) {
        model.setTwitchFollowersMode(enabled: duration != nil,
                                     duration: (duration ?? 0) / 60,
                                     onComplete: onComplete)
    }

    var body: some View {
        ChatModesView {
            SlowModeView(durations: [3, 5, 10, 30, 60, 120], action: slowModeAction)
            FollowersOnlyView(durations: [60, 300, 600, 3600], action: followersOnlyAction)
            SubscribersOnlyView(action: model.setTwitchSubscribersOnlyMode)
            EmotesOnlyView(action: model.setTwitchEmoteOnlyMode)
        }
    }
}

private struct TwitchChannelManagementView: View {
    let model: Model

    var body: some View {
        ChannelManagementView {
            StartTwitchRaidView(model: model)
            RunCommercialView(model: model)
            SendAnnouncementView(model: model)
        }
    }
}

private struct TwitchView: View {
    let model: Model
    @Binding var platform: Platform?

    var body: some View {
        NavigationLink {
            Form {
                TwitchUserModerationView(model: model)
                TwitchChatModesView(model: model)
                TwitchChannelManagementView(model: model)
            }
            .navigationTitle("Twitch")
            .onAppear {
                platform = .twitch
            }
        } label: {
            TwitchLogoAndNameView()
        }
    }
}

private struct KickUserModerationView: View {
    let model: Model

    var body: some View {
        UserModerationView {
            ForEach(ModActionType.allCases, id: \.self) {
                UserModerationItemView(model: model, action: $0, platform: .kick)
            }
        }
    }
}

private struct KickChatModesView: View {
    let model: Model

    private func slowModeAction(duration: Int?, onComplete: @escaping (OperationResult) -> Void) {
        if let duration {
            model.enableKickSlowMode(messageInterval: duration, onComplete: onComplete)
        } else {
            model.disableKickSlowMode(onComplete: onComplete)
        }
    }

    private func followersOnlyAction(duration: Int?, onComplete: @escaping (OperationResult) -> Void) {
        if let duration {
            model.enableKickFollowersMode(followingMinDuration: duration / 60, onComplete: onComplete)
        } else {
            model.disableKickFollowersMode(onComplete: onComplete)
        }
    }

    var body: some View {
        ChatModesView {
            SlowModeView(durations: [3, 5, 10, 30, 60, 120, 300], action: slowModeAction)
            FollowersOnlyView(durations: [60, 300, 600, 3600], action: followersOnlyAction)
            SubscribersOnlyView(action: model.setKickSubscribersOnlyMode)
            EmotesOnlyView(action: model.setKickEmoteOnlyMode)
        }
    }
}

private struct KickChannelManagementView: View {
    let model: Model

    var body: some View {
        ChannelManagementView {
            KickHostChannelView(model: model)
            CreatePollView(model: model)
            DeletePollView(model: model)
            CreatePredictionView(model: model)
        }
    }
}

private struct KickView: View {
    let model: Model
    @Binding var platform: Platform?

    var body: some View {
        NavigationLink {
            Form {
                KickUserModerationView(model: model)
                KickChatModesView(model: model)
                KickChannelManagementView(model: model)
            }
            .navigationTitle("Kick")
            .onAppear {
                platform = .kick
            }
        } label: {
            KickLogoAndNameView()
        }
    }
}

struct QuickButtonChatModerationView: View {
    @ObservedObject var model: Model
    @Binding var presentingModeration: Bool
    @State var platform: Platform?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TwitchView(model: model, platform: $platform)
                    KickView(model: model, platform: $platform)
                }
                ShortcutSectionView {
                    StreamingPlatformsShortcutView(stream: model.stream)
                }
            }
            .navigationTitle("Moderation")
            .toolbar {
                CloseToolbar(presenting: $presentingModeration)
            }
        }
        .sheet(isPresented: $model.showModerationAuth) {
            switch platform {
            case .twitch:
                TwitchLoginView(model: model, presenting: $model.showModerationAuth)
            default:
                EmptyView()
            }
        }
    }
}
