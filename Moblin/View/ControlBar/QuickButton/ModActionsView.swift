import SwiftUI

enum ModPlatform: String, CaseIterable, Identifiable {
    case kick = "Kick"
    case twitch = "Twitch"

    var id: Self { self }

    var logo: String {
        switch self {
        case .kick: "KickLogo"
        case .twitch: "TwitchLogo"
        }
    }
}

enum ModActionCategory: String, CaseIterable {
    case userModeration = "User Moderation"
    case chatMode = "Chat Modes"
    case chatManagement = "Chat Management"

    var icon: String {
        switch self {
        case .userModeration: "person.fill"
        case .chatMode: "bubble.left.fill"
        case .chatManagement: "gearshape.fill"
        }
    }
}

enum ModActionType: CaseIterable, Identifiable {
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

    var id: Self { self }

    func title(for platform: ModPlatform) -> String {
        switch self {
        case .ban: String(localized: "Ban User")
        case .timeout: String(localized: "Timeout User")
        case .unban: String(localized: "UnBan User")
        case .mod: String(localized: "Mod User")
        case .unmod: String(localized: "UnMod User")
        case .vip: String(localized: "VIP User")
        case .unvip: String(localized: "UnVIP User")
        case .raid:
            if platform == .kick {
                String(localized: "Host Channel")
            } else {
                String(localized: "Raid Channel")
            }
        case .slow: String(localized: "Slow Mode")
        case .slowoff: String(localized: "Slow Mode Off")
        case .followers: String(localized: "Followers Only")
        case .followersoff: String(localized: "Followers Only Off")
        case .emoteonly: String(localized: "Emote Only")
        case .emoteonlyoff: String(localized: "Emote Only Off")
        case .subscribers: String(localized: "Subscribers Only")
        case .subscribersoff: String(localized: "Subscribers Only Off")
        case .poll: String(localized: "Create Poll")
        case .deletepoll: String(localized: "Delete Poll")
        case .prediction: String(localized: "Create Prediction")
        case .commercial: String(localized: "Run Commercial")
        case .announcement: String(localized: "Send Announcement")
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
        case .ban, .timeout, .unban, .mod, .unmod, .vip, .unvip, .raid:
            .userModeration
        case .slow, .slowoff, .followers, .followersoff,
             .emoteonly, .emoteonlyoff, .subscribers, .subscribersoff:
            .chatMode
        case .poll, .deletepoll, .prediction, .commercial, .announcement:
            .chatManagement
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

enum AnnouncementColor: String, CaseIterable, Identifiable {
    case primary, blue, green, orange, purple

    var id: Self { self }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .primary: .gray
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        }
    }
}

struct ModActionsView: View {
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

    var body: some View {
        NavigationStack {
            Group {
                if availablePlatforms.isEmpty {
                    notLoggedInView
                } else {
                    actionsList
                }
            }
            .navigationTitle("Moderator Actions")
            .navigationBarTitleDisplayMode(.inline)
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

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Not Logged In")
                .font(.headline)
            Text("Please log in to Kick or Twitch in stream settings to use moderator actions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionsList: some View {
        List {
            ForEach(availablePlatforms) { platform in
                NavigationLink {
                    ModActionPlatformView(
                        platform: platform,
                        model: model,
                        showingModActions: $showingModActions
                    )
                } label: {
                    HStack(spacing: 12) {
                        Image(platform.logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        Text(platform.rawValue)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct ModActionPlatformView: View {
    let platform: ModPlatform
    let model: Model
    @Binding var showingModActions: Bool

    var body: some View {
        List {
            ForEach(ModActionCategory.allCases, id: \.self) { category in
                let actions = ModActionType.actions(for: category, platform: platform)
                if !actions.isEmpty {
                    NavigationLink {
                        ModActionCategoryView(
                            category: category,
                            platform: platform,
                            model: model,
                            showingModActions: $showingModActions
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(category.rawValue)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(platform.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ModActionCategoryView: View {
    let category: ModActionCategory
    let platform: ModPlatform
    let model: Model
    @Binding var showingModActions: Bool

    private var actions: [ModActionType] {
        ModActionType.actions(for: category, platform: platform)
    }

    var body: some View {
        List {
            ForEach(actions) { action in
                ModActionRowView(
                    action: action,
                    platform: platform,
                    model: model,
                    showingModActions: $showingModActions
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
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
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(action.title(for: platform))
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
        case .slowoff: model.setKickSlowMode(enabled: false)
        case .followersoff: model.setKickFollowersMode(enabled: false)
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
}

private struct ModActionDetailView: View {
    let action: ModActionType
    let platform: ModPlatform
    let model: Model
    @Binding var showingModActions: Bool

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
        .navigationBarTitleDisplayMode(.inline)
    }

    private func complete() {
        showingModActions = false
    }
}

private struct StandardActionFormView: View {
    let action: ModActionType
    let platform: ModPlatform
    let model: Model
    let onComplete: () -> Void
    @State private var username = ""
    @State private var reason = ""
    @State private var duration = ""

    private var canExecute: Bool {
        if action.requiresUsername && username.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        if action.requiresDuration && duration.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
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

            if action.requiresDuration {
                Section {
                    TextField("Duration in seconds", text: $duration)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Duration")
                } footer: {
                    Text(durationFooterText)
                }
            }

            if action.requiresReason {
                Section {
                    TextField("Reason", text: $reason)
                } header: {
                    Text("Reason (Optional)")
                }
            }

            Section {
                Button {
                    executeAction()
                } label: {
                    Text("Send")
                }
                .disabled(!canExecute)
            }
        }
    }

    private var durationFooterText: String {
        switch action {
        case .slow:
            if platform == .twitch {
                String(localized: "Message interval in seconds (3-120)")
            } else {
                String(localized: "Message interval in seconds")
            }
        case .followers:
            String(localized: "Minimum follow duration in minutes")
        default:
            String(localized: "Duration in seconds")
        }
    }

    private func executeAction() {
        let user = username.trimmingCharacters(in: .whitespaces)
        let durationValue = Int(duration.trimmingCharacters(in: .whitespaces))
        let banReason = reason.trimmingCharacters(in: .whitespaces)

        switch platform {
        case .kick:
            executeKickAction(user: user, durationValue: durationValue, banReason: banReason)
        case .twitch:
            executeTwitchAction(user: user, durationValue: durationValue, banReason: banReason)
        }
        onComplete()
    }

    private func executeKickAction(user: String, durationValue: Int?, banReason: String) {
        switch action {
        case .ban:
            model.banKickUser(user: user, duration: nil, reason: banReason.isEmpty ? nil : banReason)
        case .timeout:
            if let duration = durationValue {
                model.banKickUser(user: user, duration: duration)
            }
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
            if let messageInterval = durationValue {
                model.setKickSlowMode(enabled: true, messageInterval: messageInterval)
            }
        case .followers:
            if let followingMinDuration = durationValue {
                model.setKickFollowersMode(enabled: true, followingMinDuration: followingMinDuration)
            }
        default:
            break
        }
    }

    private func executeTwitchAction(user: String, durationValue: Int?, banReason: String) {
        switch action {
        case .ban:
            model.banTwitchUserByName(user: user, duration: nil, reason: banReason.isEmpty ? nil : banReason)
        case .timeout:
            if let duration = durationValue {
                model.banTwitchUserByName(user: user, duration: duration, reason: nil)
            }
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
            if let duration = durationValue {
                model.setTwitchSlowMode(enabled: true, duration: max(3, min(120, duration)))
            }
        case .followers:
            if let duration = durationValue {
                model.setTwitchFollowersMode(enabled: true, duration: duration)
            }
        default:
            break
        }
    }
}

private struct CreatePollView: View {
    let platform: ModPlatform
    let model: Model
    let onComplete: () -> Void
    @State private var title = ""
    @State private var options = ["", ""]
    @State private var duration = 30
    @State private var resultDisplayDuration = 15

    private var canExecute: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let filledOptions = options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return !trimmedTitle.isEmpty && filledOptions.count >= 2
    }

    var body: some View {
        Form {
            Section {
                TextField("Poll Question", text: $title)
            } header: {
                Text("Question")
            }

            Section {
                ForEach(options.indices, id: \.self) { index in
                    TextField("Option \(index + 1)", text: $options[index])
                }

                if options.count < 6 {
                    Button {
                        options.append("")
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Option")
                        }
                    }
                }
            } header: {
                Text("Options")
            } footer: {
                Text("At least 2 options required, up to 6 total")
            }

            Section {
                Picker("Duration", selection: $duration) {
                    Text("30 seconds").tag(30)
                    Text("2 minutes").tag(120)
                    Text("3 minutes").tag(180)
                    Text("4 minutes").tag(240)
                    Text("5 minutes").tag(300)
                }
            } header: {
                Text("Poll Duration")
            } footer: {
                Text("How long the poll will run")
            }

            if platform == .kick {
                Section {
                    Picker("Result Display", selection: $resultDisplayDuration) {
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                        Text("2 minutes").tag(120)
                        Text("3 minutes").tag(180)
                        Text("4 minutes").tag(240)
                        Text("5 minutes").tag(300)
                    }
                } header: {
                    Text("Result Display Duration")
                } footer: {
                    Text("How long results will be shown")
                }
            }

            Section {
                Button {
                    createPoll()
                } label: {
                    Text("Create Poll")
                }
                .disabled(!canExecute)
            }
        }
    }

    private func createPoll() {
        let trimmedOptions = options
            .map { $0.trimmingCharacters(in: .whitespaces) }
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

    var body: some View {
        Form {
            Section {
                TextField("Prediction Question", text: $title)
            } header: {
                Text("Question")
            }

            Section {
                TextField("Outcome 1", text: $outcome1)
                TextField("Outcome 2", text: $outcome2)
            } header: {
                Text("Outcomes")
            } footer: {
                Text("2 outcomes required")
            }

            Section {
                Picker("Duration", selection: $duration) {
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                    Text("30 minutes").tag(1800)
                }
            } header: {
                Text("Prediction Duration")
            } footer: {
                Text("How long users can make predictions")
            }

            Section {
                Button {
                    createPrediction()
                } label: {
                    Text("Create Prediction")
                }
                .disabled(!canExecute)
            }
        }
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
}

private struct RunCommercialView: View {
    let model: Model
    let onComplete: () -> Void
    @State private var duration = 30

    var body: some View {
        Form {
            Section {
                Picker("Duration", selection: $duration) {
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                    Text("90 seconds").tag(90)
                    Text("2 minutes").tag(120)
                    Text("2.5 minutes").tag(150)
                    Text("3 minutes").tag(180)
                }
            } header: {
                Text("Commercial Length")
            } footer: {
                Text("How long the commercial will run")
            }

            Section {
                Button {
                    model.startAds(seconds: duration)
                    onComplete()
                } label: {
                    Text("Run Commercial")
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
                Menu {
                    ForEach(AnnouncementColor.allCases) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Label(
                                color.displayName,
                                systemImage: selectedColor == color ? "checkmark.circle.fill" : "circle.fill"
                            )
                        }
                        .tint(color.color)
                    }
                } label: {
                    HStack {
                        Text("Color")
                        Spacer()
                        Text(selectedColor.displayName)
                            .foregroundStyle(selectedColor.color)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Announcement Color")
            }

            Section {
                Button {
                    model.sendTwitchAnnouncement(
                        message: message.trimmingCharacters(in: .whitespaces),
                        color: selectedColor.rawValue
                    )
                    onComplete()
                } label: {
                    Text("Send Announcement")
                }
                .disabled(!canSend)
            }
        }
    }
}
