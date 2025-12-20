import SwiftUI

private enum ExecutorState {
    case idle
    case inProgress
    case success
    case error
}

private class Executor: ObservableObject {
    @Published var state: ExecutorState = .idle

    func startProgress() {
        state = .inProgress
    }

    func completed(ok: Bool) {
        if ok {
            state = .success
        } else {
            state = .error
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.state = .idle
        }
    }
}

private struct ExecutorView<Content: View>: View {
    @ObservedObject var executor: Executor
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch executor.state {
        case .idle:
            content()
        case .inProgress:
            ProgressView()
        case .success:
            Text("Success")
                .foregroundStyle(.green)
        case .error:
            Text("Failed")
                .foregroundStyle(.red)
        }
    }
}

private struct ToggleActionView: View {
    let text: LocalizedStringKey
    let image: String
    let action: (Bool, @escaping (Bool) -> Void) -> Void
    @StateObject private var executor = Executor()

    private func button(text: LocalizedStringKey, on: Bool) -> some View {
        Button {
            executor.startProgress()
            action(on, executor.completed)
        } label: {
            Text(text)
        }
        .buttonStyle(.borderless)
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
    let action: (Int?, @escaping (Bool) -> Void) -> Void
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
                Button {
                    executor.startProgress()
                    action(duration, executor.completed)
                } label: {
                    Text("Send")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private enum ModActionCategory {
    case userModeration
    case channelManagement
}

private enum ModActionType: CaseIterable {
    case ban
    case timeout
    case unban
    case mod
    case unmod
    case vip
    case unvip
    case raid
    case poll
    case deletepoll
    case prediction
    case commercial
    case announcement

    func title(for platform: Platform) -> String {
        switch self {
        case .ban:
            return String(localized: "Ban")
        case .timeout:
            return String(localized: "Timeout")
        case .unban:
            return String(localized: "Unban")
        case .mod:
            return String(localized: "Mod")
        case .unmod:
            return String(localized: "Unmod")
        case .vip:
            return String(localized: "VIP")
        case .unvip:
            return String(localized: "Unvip")
        case .raid:
            if platform == .kick {
                return String(localized: "Host channel")
            } else {
                return String(localized: "Raid channel")
            }
        case .poll:
            return String(localized: "Create poll")
        case .deletepoll:
            return String(localized: "Delete poll")
        case .prediction:
            return String(localized: "Create prediction")
        case .commercial:
            return String(localized: "Run commercial")
        case .announcement:
            return String(localized: "Send announcement")
        }
    }

    var icon: String {
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
        case .raid:
            return "play.tv"
        case .poll:
            return "chart.bar"
        case .deletepoll:
            return "chart.bar.xaxis"
        case .prediction:
            return "sparkles"
        case .commercial:
            return "cup.and.saucer"
        case .announcement:
            return "megaphone"
        }
    }

    var category: ModActionCategory {
        switch self {
        case .ban, .timeout, .unban, .mod, .unmod, .vip, .unvip:
            return .userModeration
        case .raid, .poll, .deletepoll, .prediction, .commercial, .announcement:
            return .channelManagement
        }
    }

    var requiresUsername: Bool {
        switch self {
        case .ban, .timeout, .unban, .mod, .unmod, .vip, .unvip, .raid:
            true
        default:
            false
        }
    }

    var requiresReason: Bool {
        return self == .ban
    }

    var needsDetailView: Bool {
        return requiresUsername
            || requiresReason
            || self == .timeout
            || self == .poll
            || self == .prediction
            || self == .commercial
            || self == .announcement
    }

    func isSupported(by platform: Platform) -> Bool {
        switch self {
        case .poll, .deletepoll, .prediction:
            return platform == .kick
        case .commercial, .announcement:
            return platform == .twitch
        default:
            return true
        }
    }

    static func actions(for category: ModActionCategory, platform: Platform) -> [ModActionType] {
        return allCases.filter { $0.category == category && $0.isSupported(by: platform) }
    }
}

private enum AnnouncementColor: String, CaseIterable {
    case primary
    case blue
    case green
    case orange
    case purple

    func name() -> String {
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

private struct ModActionRowView: View {
    let model: Model
    let action: ModActionType
    let platform: Platform
    @StateObject private var executor = Executor()

    private func rowContent() -> some View {
        return IconAndTextView(image: action.icon, text: action.title(for: platform))
    }

    var body: some View {
        if action.needsDetailView {
            NavigationLink {
                ModActionDetailView(model: model, action: action, platform: platform)
            } label: {
                rowContent()
            }
        } else {
            HStack {
                rowContent()
                Spacer()
                ExecutorView(executor: executor) {
                    Button {
                        executor.startProgress()
                        model.deleteKickPoll(onComplete: executor.completed)
                    } label: {
                        Text("Send")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

private struct ModActionDetailView: View {
    let model: Model
    let action: ModActionType
    let platform: Platform

    var body: some View {
        Group {
            switch action {
            case .poll:
                CreatePollView(model: model)
            case .prediction:
                CreatePredictionView(model: model)
            case .commercial:
                RunCommercialView(model: model)
            case .announcement:
                SendAnnouncementView(model: model)
            default:
                StandardActionFormView(model: model, action: action, platform: platform)
            }
        }
        .navigationTitle(action.title(for: platform))
    }
}

private struct StandardActionFormView: View {
    let model: Model
    let action: ModActionType
    let platform: Platform
    @State private var username = ""
    @State private var reason = ""
    @State private var timeoutDuration = 60
    @StateObject var executor = Executor()

    private func canExecute() -> Bool {
        if action.requiresUsername && username.trim().isEmpty {
            return false
        }
        return true
    }

    private let timeoutPresets = [60, 300, 600, 1800, 3600, 21600, 86400, 604_800]

    private func executeAction(onComplete: @escaping (Bool) -> Void) {
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

    private func executeKickAction(user: String, banReason: String, onComplete: @escaping (Bool) -> Void) {
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
        case .raid:
            model.hostKickChannel(channel: user, onComplete: onComplete)
        default:
            break
        }
    }

    private func executeTwitchAction(user: String, banReason: String, onComplete: @escaping (Bool) -> Void) {
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
        case .raid:
            model.raidTwitchChannelByName(channelName: user, onComplete: onComplete)
        default:
            break
        }
    }

    var body: some View {
        Form {
            if action.requiresUsername {
                Section {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Username")
                }
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
            if action.requiresReason {
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

    private func createPoll() {
        executor.startProgress()
        model.createKickPoll(
            title: title.trim(),
            options: options.map { $0.text.trim() }.filter { !$0.isEmpty },
            duration: duration,
            resultDisplayDuration: resultDisplayDuration,
            onComplete: executor.completed
        )
    }

    var body: some View {
        Form {
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
                            createPoll()
                        }
                        .disabled(!canExecute())
                    }
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

    private func createPrediction() {
        executor.startProgress()
        model.createKickPrediction(title: title.trim(),
                                   outcomes: [outcome1.trim(), outcome2.trim()],
                                   duration: duration,
                                   onComplete: executor.completed)
    }

    var body: some View {
        Form {
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
                            createPrediction()
                        }
                        .disabled(!canExecute())
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
        Form {
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

private struct SendAnnouncementView: View {
    let model: Model
    @State private var message = ""
    @State private var color: AnnouncementColor = .primary
    @FocusState var editingText: Bool
    @StateObject private var executor = Executor()

    private func canSend() -> Bool {
        return !message.trim().isEmpty
    }

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $message)
                    .focused($editingText)
            } header: {
                Text("Message")
            } footer: {
                if isPhone() {
                    HStack {
                        Spacer()
                        Button("Done") {
                            editingText = false
                        }
                    }
                    .disabled(!editingText)
                }
            }
            Section {
                Picker("Color", selection: $color) {
                    ForEach(AnnouncementColor.allCases, id: \.self) {
                        Text($0.name())
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
    let action: (Int?, @escaping (Bool) -> Void) -> Void

    var body: some View {
        DurationActionView(text: "Slow mode", image: "tortoise", durations: durations, action: action)
    }
}

private struct FollowersOnlyView: View {
    let durations: [Int]
    let action: (Int?, @escaping (Bool) -> Void) -> Void

    var body: some View {
        DurationActionView(text: "Followers only", image: "person.2", durations: durations, action: action)
    }
}

private struct SubscribersOnlyView: View {
    let action: (Bool, @escaping (Bool) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: "Subscribers only", image: "star", action: action)
    }
}

private struct EmotesOnlyView: View {
    let action: (Bool, @escaping (Bool) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: "Emotes only", image: "face.smiling", action: action)
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
            ForEach(ModActionType.actions(for: .userModeration, platform: .twitch), id: \.self) {
                ModActionRowView(model: model, action: $0, platform: .twitch)
            }
        }
    }
}

private struct TwitchChatModesView: View {
    let model: Model

    private func slowModeAction(duration: Int?, onComplete: @escaping (Bool) -> Void) {
        model.setTwitchSlowMode(enabled: duration != nil, duration: duration) {
            onComplete($0)
        }
    }

    private func followersOnlyAction(duration: Int?, onComplete: @escaping (Bool) -> Void) {
        model.setTwitchFollowersMode(enabled: duration != nil, duration: (duration ?? 0) / 60) {
            onComplete($0)
        }
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
            ForEach(ModActionType.actions(for: .channelManagement, platform: .twitch), id: \.self) {
                ModActionRowView(model: model, action: $0, platform: .twitch)
            }
        }
    }
}

private struct TwitchView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            Form {
                TwitchUserModerationView(model: model)
                TwitchChatModesView(model: model)
                TwitchChannelManagementView(model: model)
            }
            .navigationTitle("Twitch")
        } label: {
            TwitchLogoAndNameView()
        }
    }
}

private struct KickUserModerationView: View {
    let model: Model

    var body: some View {
        UserModerationView {
            ForEach(ModActionType.actions(for: .userModeration, platform: .kick), id: \.self) {
                ModActionRowView(model: model, action: $0, platform: .kick)
            }
        }
    }
}

private struct KickChatModesView: View {
    let model: Model

    private func slowModeAction(duration: Int?, onComplete: @escaping (Bool) -> Void) {
        if let duration {
            model.enableKickSlowMode(messageInterval: duration) {
                onComplete($0)
            }
        } else {
            model.disableKickSlowMode {
                onComplete($0)
            }
        }
    }

    private func followersOnlyAction(duration: Int?, onComplete: @escaping (Bool) -> Void) {
        if let duration {
            model.enableKickFollowersMode(followingMinDuration: duration) {
                onComplete($0)
            }
        } else {
            model.disableKickFollowersMode {
                onComplete($0)
            }
        }
    }

    var body: some View {
        ChatModesView {
            SlowModeView(durations: [3, 5, 10, 30, 60, 120, 300], action: slowModeAction)
            FollowersOnlyView(durations: [1, 5, 10, 30, 60, 1440, 10080, 43200], action: followersOnlyAction)
            SubscribersOnlyView(action: model.setKickSubscribersOnlyMode)
            EmotesOnlyView(action: model.setKickEmoteOnlyMode)
        }
    }
}

private struct KickChannelManagementView: View {
    let model: Model

    var body: some View {
        ChannelManagementView {
            ForEach(ModActionType.actions(for: .channelManagement, platform: .kick), id: \.self) {
                ModActionRowView(model: model, action: $0, platform: .kick)
            }
        }
    }
}

private struct KickView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            Form {
                KickUserModerationView(model: model)
                KickChatModesView(model: model)
                KickChannelManagementView(model: model)
            }
            .navigationTitle("Kick")
        } label: {
            KickLogoAndNameView()
        }
    }
}

struct QuickButtonChatModerationView: View {
    let model: Model
    @Binding var showingModeration: Bool

    var body: some View {
        NavigationStack {
            Form {
                TwitchView(model: model)
                KickView(model: model)
            }
            .navigationTitle("Moderation")
            .toolbar {
                CloseToolbar(presenting: $showingModeration)
            }
        }
    }
}
