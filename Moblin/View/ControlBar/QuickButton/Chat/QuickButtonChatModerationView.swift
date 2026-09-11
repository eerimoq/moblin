import SwiftUI

enum ExecutorState {
    case idle
    case inProgress
    case success
    case authError
    case error
}

class Executor: ObservableObject, @unchecked Sendable {
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

    func completedNoTimer(result: OperationResult) {
        switch result {
        case .success:
            state = .idle
        case .authError:
            state = .authError
        case .error:
            state = .error
        }
    }
}

struct ExecutorView<Content: View>: View {
    @EnvironmentObject var model: Model
    @ObservedObject var executor: Executor
    var centerNonContent: Bool = false
    @ViewBuilder let content: () -> Content

    private func handleState() {
        if executor.state == .authError {
            model.showModerationAuth = true
            model.twitchLogin(stream: model.stream)
        }
    }

    var body: some View {
        Group {
            switch executor.state {
            case .idle:
                content()
            case .inProgress:
                ProgressView()
                    .id(UUID()) // Only visible first raid search if removed.
                    .hCenter(centerNonContent)
            case .success:
                Text("Success")
                    .foregroundStyle(.green)
                    .hCenter(centerNonContent)
            case .authError:
                Text("Not logged in")
                    .foregroundStyle(.red)
                    .hCenter(centerNonContent)
            case .error:
                Text("Failed")
                    .foregroundStyle(.red)
                    .hCenter(centerNonContent)
            }
        }
        .onAppear {
            handleState()
        }
        .onChange(of: executor.state) { _ in
            handleState()
        }
    }
}

struct ToggleActionView: View {
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
                    .padding(.trailing, 15)
                button(text: "Off", on: false)
            }
        }
    }
}

struct DurationActionView: View {
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
                        Text(formatShortDuration(seconds: $0))
                            .tag($0 as Int?)
                    }
                }
                .padding(.trailing, 15)
                BorderlessButtonView(text: "Send") {
                    executor.startProgress()
                    action(duration, executor.completed)
                }
            }
        }
    }
}

enum ModActionType: CaseIterable {
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
            "Ban"
        case .timeout:
            "Timeout"
        case .unban:
            "Unban"
        case .mod:
            "Mod"
        case .unmod:
            "Unmod"
        case .vip:
            "VIP"
        case .unvip:
            "UnVIP"
        }
    }

    func image() -> String {
        switch self {
        case .ban:
            "hand.raised"
        case .timeout:
            "clock"
        case .unban:
            "checkmark.circle"
        case .mod:
            "shield"
        case .unmod:
            "shield.slash"
        case .vip:
            "crown"
        case .unvip:
            "crown"
        }
    }
}

struct UserModerationItemView: View {
    let model: Model
    let action: ModActionType
    let platform: Platform
    @State private var username = ""
    @State private var reason = ""
    @State private var timeoutDuration = 60
    @StateObject var executor = Executor()
    private let timeoutPresets = [60, 300, 600, 1800, 3600, 21600, 86400, 604_800]

    private func canExecute() -> Bool {
        !username.trim().isEmpty
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
                            Text(formatShortDuration(seconds: $0))
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

struct ActionRowView: View {
    let text: LocalizedStringKey
    let image: String
    let action: (@escaping (OperationResult) -> Void) -> Void
    @StateObject private var executor = Executor()

    var body: some View {
        HStack {
            IconAndTextLocalizedView(image: image, text: text)
            Spacer()
            ExecutorView(executor: executor) {
                BorderlessButtonView(text: "Send") {
                    executor.startProgress()
                    action(executor.completed)
                }
            }
        }
    }
}

struct PollOption: Identifiable {
    let id: UUID = .init()
    var text: String = ""
}

func canCreatePoll(title: String, options: [PollOption]) -> Bool {
    !title.trim().isEmpty && options.filter { !$0.text.trim().isEmpty }.count >= 2
}

func pollOptionTitles(options: [PollOption]) -> [String] {
    options.map { $0.text.trim() }.filter { !$0.isEmpty }
}

struct PollOptionsSectionView: View {
    let header: LocalizedStringKey
    let placeholder: LocalizedStringKey
    let kind: String
    @Binding var options: [PollOption]
    let maxCount: Int

    var body: some View {
        Section {
            ForEach($options) { $option in
                TextField(placeholder, text: $option.text)
                    .deleteDisabled(options.count <= 2)
                    .contextMenuDeleteButton(disabled: options.count <= 2) {
                        options.removeAll { $0.id == option.id }
                    }
            }
            .onDelete { offsets in
                options.remove(atOffsets: offsets)
            }
            if options.count < maxCount {
                AddButtonView {
                    options.append(PollOption())
                }
            }
        } header: {
            Text(header)
        } footer: {
            SwipeLeftToDeleteHelpView(kind: kind)
        }
    }
}

struct ChannelImageView: View {
    let image: String?

    var body: some View {
        Group {
            if let image, let url = URL(string: image) {
                CacheAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Image("AppIconNoBackground")
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Image("AppIconNoBackground")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
}

struct RaidChannelView: View {
    let buttonText: LocalizedStringKey
    let channel: String
    let category: String
    let title: String
    let image: String?
    let isLive: Bool
    let viewerCount: Int?
    let action: (@escaping (OperationResult) -> Void) -> Void
    @StateObject private var executor = Executor()

    var body: some View {
        HStack {
            ChannelImageView(image: image)
            VStack(alignment: .leading) {
                Text(channel)
                if isLive {
                    Text(category)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                } else {
                    Text("Offline")
                        .font(.caption)
                }
            }
            Spacer()
            if let viewerCount {
                HStack(spacing: 2) {
                    Image(systemName: "eye")
                    Text(countFormatter.format(viewerCount))
                }
                .font(.caption)
            }
            if isLive {
                ExecutorView(executor: executor) {
                    BorderlessButtonView(text: buttonText) {
                        executor.startProgress()
                        action(executor.completed)
                    }
                }
            }
        }
    }
}

struct SlowModeView: View {
    let durations: [Int]
    let action: (Int?, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        DurationActionView(text: "Slow mode", image: "tortoise", durations: durations, action: action)
    }
}

struct FollowersOnlyView: View {
    let durations: [Int]
    let action: (Int?, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        DurationActionView(text: "Followers only", image: "person.2", durations: durations, action: action)
    }
}

struct SubscribersOnlyView: View {
    let action: (Bool, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: "Subscribers only", image: "star", action: action)
    }
}

struct EmotesOnlyView: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: (Bool, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: "Emotes only",
                         image: colorScheme == .light ? "face.smiling" : "face.smiling.inverse",
                         action: action)
    }
}

struct NavigationLinkView<Content: View>: View {
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

struct QuickButtonChatModerationView: View {
    @ObservedObject var model: Model
    @Binding var presentingModeration: Bool
    @State var platform: Platform?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    QuickButtonChatModerationTwitchView(model: model, platform: $platform)
                    QuickButtonChatModerationKickView(model: model, platform: $platform)
                }
                ShortcutSectionView {
                    StreamingPlatformsShortcutView(model: model, stream: model.stream)
                }
            }
            .navigationTitle("Moderation")
            .navigationBarTitleDisplayMode(.inline)
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
