import SwiftUI

private enum ModPlatform: String, CaseIterable {
    case kick = "Kick"
    case twitch = "Twitch"

    var logo: String {
        switch self {
        case .kick: "KickLogo"
        case .twitch: "TwitchLogo"
        }
    }
}

private enum ModActionCategory: String, CaseIterable {
    case userModeration = "User moderation"
    case chatMode = "Chat modes"
    case channelManagement = "Channel management"

    var icon: String {
        switch self {
        case .userModeration: "person.fill"
        case .chatMode: "bubble.left.fill"
        case .channelManagement: "gearshape.fill"
        }
    }
}

private enum ModActionType: CaseIterable {
    case ban, timeout, unban
    case mod, unmod
    case vip, unvip
    case raid
    case slow, slowoff
    case followers, followersoff
    case emoteonly, emoteonlyoff
    case subscribers, subscribersoff
    case poll, deletepoll
    case prediction
    case commercial
    case announcement

    func title(for platform: ModPlatform) -> String {
        switch self {
        case .ban: String(localized: "Ban")
        case .timeout: String(localized: "Timeout")
        case .unban: String(localized: "Unban")
        case .mod: String(localized: "Mod")
        case .unmod: String(localized: "Unmod")
        case .vip: String(localized: "VIP")
        case .unvip: String(localized: "Unvip")
        case .raid:
            if platform == .kick {
                String(localized: "Host channel")
            } else {
                String(localized: "Raid channel")
            }
        case .slow: String(localized: "Slow mode")
        case .slowoff: String(localized: "Slow mode off")
        case .followers: String(localized: "Followers only")
        case .followersoff: String(localized: "Followers only off")
        case .emoteonly: String(localized: "Emote only")
        case .emoteonlyoff: String(localized: "Emote only off")
        case .subscribers: String(localized: "Subscribers only")
        case .subscribersoff: String(localized: "Subscribers only off")
        case .poll: String(localized: "Create poll")
        case .deletepoll: String(localized: "Delete poll")
        case .prediction: String(localized: "Create prediction")
        case .commercial: String(localized: "Run commercial")
        case .announcement: String(localized: "Send announcement")
        }
    }

    var icon: String {
        switch self {
        case .ban: "hand.raised.fill"
        case .timeout: "clock.fill"
        case .unban: "checkmark.circle.fill"
        case .mod: "shield.fill"
        case .unmod: "shield.slash.fill"
        case .vip: "crown.fill"
        case .unvip: "crown"
        case .raid: "tv.fill"
        case .slow: "tortoise.fill"
        case .slowoff: "hare.fill"
        case .followers: "person.2.fill"
        case .followersoff: "person.2.slash.fill"
        case .emoteonly: "face.smiling.fill"
        case .emoteonlyoff: "text.bubble.fill"
        case .subscribers: "star.fill"
        case .subscribersoff: "star.slash.fill"
        case .poll: "chart.bar.fill"
        case .deletepoll: "chart.bar.xaxis"
        case .prediction: "sparkles"
        case .commercial: "dollarsign.circle.fill"
        case .announcement: "megaphone.fill"
        }
    }

    var category: ModActionCategory {
        switch self {
        case .ban, .timeout, .unban, .mod, .unmod, .vip, .unvip:
            .userModeration
        case .slow, .slowoff, .followers, .followersoff,
             .emoteonly, .emoteonlyoff, .subscribers, .subscribersoff:
            .chatMode
        case .raid, .poll, .deletepoll, .prediction, .commercial, .announcement:
            .channelManagement
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
        self == .ban
    }

    var requiresDuration: Bool {
        switch self {
        case .timeout, .slow, .followers:
            true
        default:
            false
        }
    }

    var needsDetailView: Bool {
        requiresUsername || requiresReason || requiresDuration ||
            self == .poll || self == .prediction || self == .commercial || self == .announcement
    }

    func isSupported(by platform: ModPlatform) -> Bool {
        switch self {
        case .poll, .deletepoll, .prediction:
            platform == .kick
        case .commercial, .announcement:
            platform == .twitch
        default:
            true
        }
    }

    static func actions(for category: ModActionCategory, platform: ModPlatform) -> [ModActionType] {
        allCases.filter { $0.category == category && $0.isSupported(by: platform) }
    }
}

private enum AnnouncementColor: String, CaseIterable {
    case primary, blue, green, orange, purple

    var displayName: String {
        switch self {
        case .primary: "⚪ Primary"
        case .blue: "🔵 Blue"
        case .green: "🟢 Green"
        case .orange: "🟠 Orange"
        case .purple: "🟣 Purple"
        }
    }
}

private struct ModActionPlatformView: View {
    let model: Model
    let platform: ModPlatform
    @Binding var showingModActions: Bool

    var body: some View {
        Form {
            ForEach(ModActionCategory.allCases, id: \.self) { category in
                let actions = ModActionType.actions(for: category, platform: platform)
                if !actions.isEmpty {
                    NavigationLink {
                        ModActionCategoryView(
                            model: model,
                            category: category,
                            platform: platform,
                            showingModActions: $showingModActions
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(category.rawValue)
                        }
                    }
                }
            }
        }
        .navigationTitle(platform.rawValue)
    }
}

private struct ModActionCategoryView: View {
    let model: Model
    let category: ModActionCategory
    let platform: ModPlatform
    @Binding var showingModActions: Bool

    private var actions: [ModActionType] {
        ModActionType.actions(for: category, platform: platform)
    }

    var body: some View {
        Form {
            ForEach(actions, id: \.self) { action in
                ModActionRowView(
                    action: action,
                    platform: platform,
                    model: model,
                    showingModActions: $showingModActions
                )
            }
        }
        .navigationTitle(category.rawValue)
    }
}

private struct ModActionRowView: View {
    let action: ModActionType
    let platform: ModPlatform
    let model: Model
    @Binding var showingModActions: Bool

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: action.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(action.title(for: platform))
        }
    }

    private func executeAction() {
        switch platform {
        case .kick:
            executeKickAction()
        case .twitch:
            executeTwitchAction()
        }
        showingModActions = false
    }

    private func executeKickAction() {
        switch action {
        case .deletepoll: model.deleteKickPoll()
        case .slowoff: model.disableKickSlowMode()
        case .followersoff: model.disableKickFollowersMode()
        case .emoteonlyoff: model.setKickEmoteOnlyMode(enabled: false)
        case .emoteonly: model.setKickEmoteOnlyMode(enabled: true)
        case .subscribersoff: model.setKickSubscribersOnlyMode(enabled: false)
        case .subscribers: model.setKickSubscribersOnlyMode(enabled: true)
        default: break
        }
    }

    private func executeTwitchAction() {
        switch action {
        case .slowoff: model.setTwitchSlowMode(enabled: false)
        case .followersoff: model.setTwitchFollowersMode(enabled: false)
        case .emoteonlyoff: model.setTwitchEmoteOnlyMode(enabled: false)
        case .emoteonly: model.setTwitchEmoteOnlyMode(enabled: true)
        case .subscribersoff: model.setTwitchSubscribersOnlyMode(enabled: false)
        case .subscribers: model.setTwitchSubscribersOnlyMode(enabled: true)
        default: break
        }
    }

    var body: some View {
        if action.needsDetailView {
            NavigationLink {
                ModActionDetailView(
                    action: action,
                    platform: platform,
                    model: model,
                    showingModActions: $showingModActions
                )
            } label: {
                rowContent
            }
        } else {
            Button {
                executeAction()
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ModActionDetailView: View {
    let action: ModActionType
    let platform: ModPlatform
    let model: Model
    @Binding var showingModActions: Bool

    private func complete() {
        showingModActions = false
    }

    var body: some View {
        Group {
            switch action {
            case .poll:
                CreatePollView(platform: platform, model: model, onComplete: complete)
            case .prediction:
                CreatePredictionView(platform: platform, model: model, onComplete: complete)
            case .commercial:
                RunCommercialView(model: model, onComplete: complete)
            case .announcement:
                SendAnnouncementView(model: model, onComplete: complete)
            default:
                StandardActionFormView(
                    action: action,
                    platform: platform,
                    model: model,
                    onComplete: complete
                )
            }
        }
        .navigationTitle(action.title(for: platform))
    }
}

private struct StandardActionFormView: View {
    let action: ModActionType
    let platform: ModPlatform
    let model: Model
    let onComplete: () -> Void
    @State private var username = ""
    @State private var reason = ""
    @State private var timeoutDuration = 60
    @State private var slowModeDuration = 10
    @State private var followersDuration = 10

    private var canExecute: Bool {
        if action.requiresUsername && username.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }

    private var timeoutPresets: [(String, Int)] {
        [
            ("1 minute", 60),
            ("5 minutes", 300),
            ("10 minutes", 600),
            ("30 minutes", 1800),
            ("1 hour", 3600),
            ("6 hours", 21600),
            ("1 day", 86400),
            ("1 week", 604_800),
        ]
    }

    private var slowModePresets: [Int] {
        if platform == .twitch {
            [3, 5, 10, 30, 60, 120]
        } else {
            [3, 5, 10, 30, 60, 120, 300]
        }
    }

    private var followersPresets: [(String, Int)] {
        [
            ("0 minutes", 0),
            ("1 minute", 1),
            ("5 minutes", 5),
            ("10 minutes", 10),
            ("30 minutes", 30),
            ("1 hour", 60),
            ("1 day", 1440),
            ("1 week", 10080),
            ("1 month", 43200),
        ]
    }

    private func executeAction() {
        let user = username.trimmingCharacters(in: .whitespaces)
        let banReason = reason.trimmingCharacters(in: .whitespaces)
        switch platform {
        case .kick:
            executeKickAction(user: user, banReason: banReason)
        case .twitch:
            executeTwitchAction(user: user, banReason: banReason)
        }
        onComplete()
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
        case .slow:
            model.enableKickSlowMode(messageInterval: slowModeDuration)
        case .followers:
            model.enableKickFollowersMode(followingMinDuration: followersDuration)
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
        case .slow:
            model.setTwitchSlowMode(enabled: true, duration: slowModeDuration)
        case .followers:
            model.setTwitchFollowersMode(enabled: true, duration: followersDuration)
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
                        ForEach(timeoutPresets, id: \.1) { preset in
                            Text(preset.0)
                                .tag(preset.1)
                        }
                    }
                }
            }
            if action == .slow {
                Section {
                    Picker("Message interval", selection: $slowModeDuration) {
                        ForEach(slowModePresets, id: \.self) {
                            Text(formatSecondsAndMinutes(seconds: $0))
                        }
                    }
                }
            }
            if action == .followers {
                Section {
                    Picker("Minimum follow time", selection: $followersDuration) {
                        ForEach(followersPresets, id: \.1) { preset in
                            Text(preset.0)
                                .tag(preset.1)
                        }
                    }
                }
            }
            if action.requiresReason {
                Section {
                    TextField("Reason", text: $reason)
                } header: {
                    Text("Reason (optional)")
                }
            }
            Section {
                TextButtonView("Send") {
                    executeAction()
                }
                .disabled(!canExecute)
            }
        }
    }
}

private struct PollOption: Identifiable {
    let id: UUID = .init()
    var text: String = ""
}

private struct CreatePollView: View {
    let platform: ModPlatform
    let model: Model
    let onComplete: () -> Void
    @State private var title: String = ""
    @State private var options = [PollOption(), PollOption()]
    @State private var duration: Int = 30
    @State private var resultDisplayDuration: Int = 15

    private var canExecute: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let filledOptions = options.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        return !trimmedTitle.isEmpty && filledOptions.count >= 2
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $title)
            } header: {
                Text("Question")
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
                    TextButtonView("Add option") {
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
                        Text(formatSecondsAndMinutes(seconds: $0))
                    }
                }
            } header: {
                Text("Poll duration")
            }
            if platform == .kick {
                Section {
                    Picker("Result display", selection: $resultDisplayDuration) {
                        ForEach([15, 30, 120, 180, 240, 300], id: \.self) {
                            Text(formatSecondsAndMinutes(seconds: $0))
                        }
                    }
                } header: {
                    Text("Result display duration")
                }
            }
            Section {
                TextButtonView("Create poll") {
                    createPoll()
                }
                .disabled(!canExecute)
            }
        }
    }

    private func createPoll() {
        let trimmedOptions = options
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        switch platform {
        case .kick:
            model.createKickPoll(
                title: title.trimmingCharacters(in: .whitespaces),
                options: trimmedOptions,
                duration: duration,
                resultDisplayDuration: resultDisplayDuration
            )
        case .twitch:
            break
        }
        onComplete()
    }
}

private struct CreatePredictionView: View {
    let platform: ModPlatform
    let model: Model
    let onComplete: () -> Void
    @State private var title = ""
    @State private var outcome1 = ""
    @State private var outcome2 = ""
    @State private var duration = 300

    private var canExecute: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
            !outcome1.trimmingCharacters(in: .whitespaces).isEmpty &&
            !outcome2.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createPrediction() {
        let outcomes = [
            outcome1.trimmingCharacters(in: .whitespaces),
            outcome2.trimmingCharacters(in: .whitespaces),
        ]
        switch platform {
        case .kick:
            model.createKickPrediction(
                title: title.trimmingCharacters(in: .whitespaces),
                outcomes: outcomes,
                duration: duration
            )
        case .twitch:
            break
        }
        onComplete()
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $title)
            } header: {
                Text("Question")
            }
            Section {
                TextField("", text: $outcome1)
                TextField("", text: $outcome2)
            } header: {
                Text("Outcomes")
            }
            Section {
                Picker("Duration", selection: $duration) {
                    ForEach([60, 300, 600, 1800], id: \.self) {
                        Text(formatSecondsAndMinutes(seconds: $0))
                    }
                }
            } header: {
                Text("Prediction duration")
            }
            Section {
                TextButtonView("Create prediction") {
                    createPrediction()
                }
                .disabled(!canExecute)
            }
        }
    }
}

private struct RunCommercialView: View {
    let model: Model
    let onComplete: () -> Void
    @State private var duration = 30

    var body: some View {
        Form {
            Section {
                Picker("Duration", selection: $duration) {
                    ForEach([30, 60, 90, 120, 180], id: \.self) {
                        Text(formatSecondsAndMinutes(seconds: $0))
                    }
                }
            } header: {
                Text("Commercial duration")
            }
            Section {
                TextButtonView("Run commercial") {
                    model.startAds(seconds: duration)
                    onComplete()
                }
            }
        }
    }
}

private struct SendAnnouncementView: View {
    let model: Model
    let onComplete: () -> Void
    @State private var message = ""
    @State private var selectedColor: AnnouncementColor = .primary

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Announcement message", text: $message, axis: .vertical)
                    .lineLimit(3 ... 6)
            } header: {
                Text("Message")
            }
            Section {
                Picker("Color", selection: $selectedColor) {
                    ForEach(AnnouncementColor.allCases, id: \.self) { color in
                        Text(color.displayName)
                            .tag(color)
                    }
                }
            }
            Section {
                TextButtonView("Send announcement") {
                    model.sendTwitchAnnouncement(
                        message: message.trimmingCharacters(in: .whitespaces),
                        color: selectedColor.rawValue
                    )
                    onComplete()
                }
                .disabled(!canSend)
            }
        }
    }
}

struct QuickButtonChatModerationView: View {
    let model: Model
    @Binding var showingModActions: Bool

    private var availablePlatforms: [ModPlatform] {
        var platforms: [ModPlatform] = []
        if model.stream.twitchLoggedIn {
            platforms.append(.twitch)
        }
        if model.stream.kickLoggedIn {
            platforms.append(.kick)
        }
        return platforms
    }

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Not logged in")
                .font(.headline)
            Text("Please log in to Kick or Twitch in stream settings to use moderator actions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var actionsList: some View {
        Form {
            ForEach(availablePlatforms, id: \.self) { platform in
                NavigationLink {
                    ModActionPlatformView(
                        model: model,
                        platform: platform,
                        showingModActions: $showingModActions
                    )
                } label: {
                    HStack(spacing: 12) {
                        Image(platform.logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Text(platform.rawValue)
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availablePlatforms.isEmpty {
                    notLoggedInView
                } else {
                    actionsList
                }
            }
            .navigationTitle("Moderation")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingModActions = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}
