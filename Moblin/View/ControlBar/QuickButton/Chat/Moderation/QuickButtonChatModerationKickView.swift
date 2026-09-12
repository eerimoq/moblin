import SwiftUI

private struct CreatePollView: View {
    let model: Model
    @State private var title: String = ""
    @State private var options = [PollOption(), PollOption()]
    @State private var duration: Int = 30
    @State private var resultDisplayDuration: Int = 15
    @StateObject private var executor = Executor()

    var body: some View {
        NavigationLinkView(text: "Create poll", image: "chart.bar") {
            Section("Title") {
                TextField("Title", text: $title)
            }
            PollOptionsSectionView(header: "Options",
                                   placeholder: "Option",
                                   kind: String(localized: "an option"),
                                   options: $options,
                                   maxCount: 6)
            Section {
                Picker("Duration", selection: $duration) {
                    ForEach([30, 120, 180, 240, 300], id: \.self) {
                        Text(formatShortDuration(seconds: $0))
                    }
                }
            }
            Section {
                Picker("Result display duration", selection: $resultDisplayDuration) {
                    ForEach([15, 30, 120, 180, 240, 300], id: \.self) {
                        Text(formatShortDuration(seconds: $0))
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
                                options: pollOptionTitles(options: options),
                                duration: duration,
                                resultDisplayDuration: resultDisplayDuration,
                                onComplete: executor.completed
                            )
                        }
                        .disabled(!canCreatePoll(title: title, options: options))
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
        !title.trim().isEmpty && !outcome1.trim().isEmpty && !outcome2.trim().isEmpty
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
                        Text(formatShortDuration(seconds: $0))
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

private struct RaidChannelSearchView: View {
    let model: Model
    @State private var searchText: String = ""
    @State private var channels: [KickLiveSearchChannel] = []
    @StateObject private var executor = Executor()

    var body: some View {
        Section {
            TextField("Search", text: $searchText)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _ in
                    guard !searchText.isEmpty else {
                        channels = []
                        return
                    }
                    executor.startProgress()
                    model.searchKickChannels(query: searchText) { results in
                        if let results {
                            channels = results.sorted(by: {
                                let searchText = searchText.lowercased()
                                let first = $0.username.lowercased()
                                let second = $1.username.lowercased()
                                if first.hasPrefix(searchText) {
                                    return true
                                } else if second.hasPrefix(searchText) {
                                    return false
                                } else {
                                    return true
                                }
                            })
                            executor.completedNoTimer(result: .success(Data()))
                        } else {
                            executor.completedNoTimer(result: .error)
                        }
                    }
                }
        }
        Section {
            ExecutorView(executor: executor, centerNonContent: true) {
                ForEach(channels) { channel in
                    RaidChannelView(buttonText: "Raid",
                                    channel: channel.username,
                                    category: channel.category ?? "",
                                    title: "",
                                    image: channel.profile_pic,
                                    isLive: channel.is_live,
                                    viewerCount: channel.viewers_count)
                    {
                        model.hostKickChannel(channel: channel.username, onComplete: $0)
                    }
                }
            }
        }
    }
}

private struct HostChannelView: View {
    let model: Model
    @State private var channels: [KickFollowedChannel] = []
    @State private var cursor: Int?
    @State private var isLoading = false

    private func loadMoreChannels() {
        guard !isLoading else {
            return
        }
        isLoading = true
        model.createKickApi(stream: model.stream).getFollowedChannels(cursor: cursor) { response in
            isLoading = false
            if let response {
                channels.append(contentsOf: response.channels)
                cursor = response.nextCursor
            }
        }
    }

    var body: some View {
        NavigationLinkView(text: "Raid channel", image: "play.tv") {
            RaidChannelSearchView(model: model)
            Section {
                ForEach(channels.filter(\.is_live)) { channel in
                    RaidChannelView(buttonText: "Raid",
                                    channel: channel.user_username,
                                    category: channel.category_name ?? "",
                                    title: channel.session_title ?? "",
                                    image: channel.profile_picture,
                                    isLive: true,
                                    viewerCount: channel.viewer_count)
                    {
                        model.hostKickChannel(channel: channel.user_username, onComplete: $0)
                    }
                }
                if isLoading {
                    HCenter {
                        ProgressView()
                    }
                } else if cursor != nil {
                    HCenter {
                        BorderlessButtonView(text: "Load more") {
                            loadMoreChannels()
                        }
                    }
                }
            } header: {
                Text("Followed channels")
            }
            .onAppear {
                channels = []
                loadMoreChannels()
            }
        }
    }
}

private struct ShowViewCountView: View {
    let action: (Bool, @escaping (OperationResult) -> Void) -> Void

    var body: some View {
        ToggleActionView(text: "Show view count on channel", image: "eye", action: action)
    }
}

struct QuickButtonChatModerationKickView: View {
    let model: Model
    @Binding var platform: Platform?

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
        NavigationLink {
            Form {
                Section {
                    HostChannelView(model: model)
                    CreatePollView(model: model)
                    ActionRowView(text: "Delete poll", image: "chart.bar") {
                        model.deleteKickPoll(onComplete: $0)
                    }
                    CreatePredictionView(model: model)
                }
                Section {
                    SlowModeView(durations: [3, 5, 10, 30, 60, 120, 300], action: slowModeAction)
                    FollowersOnlyView(durations: [60, 300, 600, 3600], action: followersOnlyAction)
                    SubscribersOnlyView(action: model.setKickSubscribersOnlyMode)
                    EmotesOnlyView(action: model.setKickEmoteOnlyMode)
                    ShowViewCountView(action: model.setKickShowViewCount)
                }
                Section {
                    ForEach(ModActionType.allCases, id: \.self) {
                        UserModerationItemView(model: model, action: $0, platform: .kick)
                    }
                }
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
