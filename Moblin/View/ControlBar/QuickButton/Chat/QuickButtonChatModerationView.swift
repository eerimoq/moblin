import SwiftUI

private enum ModActionCategory: String, CaseIterable {
    case userModeration = "User moderation"
    case channelManagement = "Channel management"

    var icon: String {
        switch self {
        case .userModeration:
            return "person"
        case .channelManagement:
            return "gearshape"
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

    var requiresDuration: Bool {
        return self == .timeout
    }

    var needsDetailView: Bool {
        requiresUsername || requiresReason || requiresDuration ||
            self == .poll || self == .prediction || self == .commercial || self == .announcement
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
        allCases.filter { $0.category == category && $0.isSupported(by: platform) }
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

private struct ModActionCategoryView: View {
    let model: Model
    let category: ModActionCategory
    let platform: Platform

    private var actions: [ModActionType] {
        ModActionType.actions(for: category, platform: platform)
    }

    var body: some View {
        Form {
            ForEach(actions, id: \.self) { action in
                ModActionRowView(model: model, action: action, platform: platform)
            }
        }
        .navigationTitle(category.rawValue)
    }
}

private struct ModActionRowView: View {
    let model: Model
    let action: ModActionType
    let platform: Platform

    private var rowContent: some View {
        IconAndTextView(image: action.icon, text: action.title(for: platform))
    }

    private func executeAction() {
        switch platform {
        case .kick:
            executeKickAction()
        default:
            break
        }
    }

    private func executeKickAction() {
        switch action {
        case .deletepoll:
            return model.deleteKickPoll()
        default:
            break
        }
    }

    var body: some View {
        if action.needsDetailView {
            NavigationLink {
                ModActionDetailView(model: model, action: action, platform: platform)
            } label: {
                rowContent
            }
        } else {
            HStack {
                rowContent
                Spacer()
                Button {
                    executeAction()
                } label: {
                    Text("Send")
                }
                .buttonStyle(.borderless)
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

    private func canExecute() -> Bool {
        if action.requiresUsername && username.trim().isEmpty {
            return false
        }
        return true
    }

    private let timeoutPresets = [60, 300, 600, 1800, 3600, 21600, 86400, 604_800]

    private func executeAction() {
        let user = username.trim()
        let banReason = reason.trim()
        switch platform {
        case .kick:
            executeKickAction(user: user, banReason: banReason)
        case .twitch:
            executeTwitchAction(user: user, banReason: banReason)
        default:
            break
        }
    }

    private func executeKickAction(user: String, banReason: String) {
        switch action {
        case .ban:
            model.banKickUser(user: user, duration: nil, reason: banReason.isEmpty ? nil : banReason)
        case .timeout:
            model.banKickUser(user: user, duration: timeoutDuration)
        case .unban:
            model.unbanKickUser(user: user)
        case .mod:
            model.modKickUser(user: user)
        case .unmod:
            model.unmodKickUser(user: user)
        case .vip:
            model.vipKickUser(user: user)
        case .unvip:
            model.unvipKickUser(user: user)
        case .raid:
            model.hostKickChannel(channel: user)
        default:
            break
        }
    }

    private func executeTwitchAction(user: String, banReason: String) {
        switch action {
        case .ban:
            model.banTwitchUser(user: user, duration: nil, reason: banReason.isEmpty ? nil : banReason)
        case .timeout:
            model.banTwitchUser(user: user, duration: timeoutDuration, reason: nil)
        case .unban:
            model.unbanTwitchUser(user: user)
        case .mod:
            model.modTwitchUser(user: user)
        case .unmod:
            model.unmodTwitchUser(user: user)
        case .vip:
            model.vipTwitchUser(user: user)
        case .unvip:
            model.unvipTwitchUser(user: user)
        case .raid:
            model.raidTwitchChannelByName(channelName: user)
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
                TextButtonView("Send") {
                    executeAction()
                }
                .disabled(!canExecute())
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

    private func canExecute() -> Bool {
        let trimmedTitle = title.trim()
        let filledOptions = options.filter { !$0.text.trim().isEmpty }
        return !trimmedTitle.isEmpty && filledOptions.count >= 2
    }

    private func createPoll() {
        model.createKickPoll(
            title: title.trim(),
            options: options.map { $0.text.trim() }.filter { !$0.isEmpty },
            duration: duration,
            resultDisplayDuration: resultDisplayDuration
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
                CreateButtonView {
                    createPoll()
                }
                .disabled(!canExecute())
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

    private func canExecute() -> Bool {
        return !title.trim().isEmpty && !outcome1.trim().isEmpty && !outcome2.trim().isEmpty
    }

    private func createPrediction() {
        model.createKickPrediction(title: title.trim(),
                                   outcomes: [outcome1.trim(), outcome2.trim()],
                                   duration: duration)
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
                CreateButtonView {
                    createPrediction()
                }
                .disabled(!canExecute())
            }
        }
    }
}

private struct RunCommercialView: View {
    let model: Model
    @State private var duration = 30

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
                TextButtonView("Run commercial") {
                    model.startAds(seconds: duration)
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
                TextButtonView("Send") {
                    model.sendTwitchAnnouncement(message: message.trim(), color: color.rawValue)
                }
                .disabled(!canSend())
            }
        }
    }
}

private enum ActionState {
    case idle
    case inProgress
    case success
    case error
}

private struct ToggleActionView: View {
    let text: String
    let image: String
    let action: (Bool, @escaping (Bool) -> Void) -> Void
    @State private var state: ActionState = .idle

    private func performAction(on: Bool) {
        state = .inProgress
        action(on) { ok in
            if ok {
                state = .success
            } else {
                state = .error
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                state = .idle
            }
        }
    }

    private func button(text: LocalizedStringKey, on: Bool) -> some View {
        Button {
            performAction(on: on)
        } label: {
            Text(text)
        }
        .buttonStyle(.borderless)
    }

    var body: some View {
        HStack {
            IconAndTextView(image: image, text: text)
            Spacer()
            switch state {
            case .idle:
                button(text: "On", on: true)
                    .padding([.trailing], 15)
                button(text: "Off", on: false)
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
}

private struct DurationActionView: View {
    let text: String
    let image: String
    let durations: [Int]
    let action: (Int?, @escaping (Bool) -> Void) -> Void
    @State private var state: ActionState = .idle
    @State private var duration: Int?

    private func performAction() {
        state = .inProgress
        action(duration) { ok in
            if ok {
                state = .success
            } else {
                state = .error
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                state = .idle
            }
        }
    }

    var body: some View {
        HStack {
            IconAndTextView(image: image, text: text)
            Spacer()
            switch state {
            case .idle:
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
                    performAction()
                } label: {
                    Text("Send")
                }
                .buttonStyle(.borderless)
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
}

private struct TwitchUserModerationView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            Form {
                ForEach(ModActionType.actions(for: .userModeration, platform: .twitch), id: \.self) {
                    ModActionRowView(model: model, action: $0, platform: .twitch)
                }
            }
            .navigationTitle("User moderation")
        } label: {
            IconAndTextView(image: "person", text: String(localized: "User moderation"))
        }
    }
}

private struct SlowModeView: View {
    let durations: [Int]
    let action: (Int?, @escaping (Bool) -> Void) -> Void

    var body: some View {
        DurationActionView(text: String(localized: "Slow mode"),
                           image: "tortoise",
                           durations: durations,
                           action: action)
    }
}

private struct FollowersOnlyView: View {
    let durations: [Int]
    let action: (Int?, @escaping (Bool) -> Void) -> Void

    var body: some View {
        DurationActionView(text: String(localized: "Followers only"),
                           image: "person.2",
                           durations: durations,
                           action: action)
    }
}

private struct SubscribersOnlyView: View {
    let action: (Bool, @escaping (Bool) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: String(localized: "Subscribers only"), image: "star", action: action)
    }
}

private struct EmotesOnlyView: View {
    let action: (Bool, @escaping (Bool) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: String(localized: "Emotes only"), image: "face.smiling", action: action)
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
        NavigationLink {
            Form {
                SlowModeView(durations: [3, 5, 10, 30, 60, 120], action: slowModeAction)
                FollowersOnlyView(durations: [60, 300, 600, 3600], action: followersOnlyAction)
                SubscribersOnlyView(action: model.setTwitchSubscribersOnlyMode)
                EmotesOnlyView(action: model.setTwitchEmoteOnlyMode)
            }
            .navigationTitle("Chat modes")
        } label: {
            IconAndTextView(image: "bubble.left", text: String(localized: "Chat modes"))
        }
    }
}

private struct TwitchChannelManagementView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            Form {
                ForEach(ModActionType.actions(for: .channelManagement, platform: .twitch), id: \.self) {
                    ModActionRowView(model: model, action: $0, platform: .twitch)
                }
            }
            .navigationTitle("Channel management")
        } label: {
            IconAndTextView(image: "gearshape", text: String(localized: "Channel management"))
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
        NavigationLink {
            Form {
                ForEach(ModActionType.actions(for: .userModeration, platform: .kick), id: \.self) {
                    ModActionRowView(model: model, action: $0, platform: .kick)
                }
            }
            .navigationTitle("User moderation")
        } label: {
            IconAndTextView(image: "person", text: String(localized: "User moderation"))
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
        NavigationLink {
            Form {
                SlowModeView(durations: [3, 5, 10, 30, 60, 120, 300], action: slowModeAction)
                FollowersOnlyView(durations: [1, 5, 10, 30, 60, 1440, 10080, 43200], action: followersOnlyAction)
                SubscribersOnlyView(action: model.setKickSubscribersOnlyMode)
                EmotesOnlyView(action: model.setKickEmoteOnlyMode)
            }
            .navigationTitle("Chat modes")
        } label: {
            IconAndTextView(image: "bubble.left", text: String(localized: "Chat modes"))
        }
    }
}

private struct KickChannelManagementView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            Form {
                ForEach(ModActionType.actions(for: .channelManagement, platform: .kick), id: \.self) {
                    ModActionRowView(model: model, action: $0, platform: .kick)
                }
            }
            .navigationTitle("Channel management")
        } label: {
            IconAndTextView(image: "gearshape", text: String(localized: "Channel management"))
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
