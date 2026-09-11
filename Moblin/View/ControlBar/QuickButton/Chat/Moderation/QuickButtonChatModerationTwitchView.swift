import SwiftUI

private struct CreatePollView: View {
    let model: Model
    let onCreated: () -> Void
    @State private var title = ""
    @State private var options = [PollOption(), PollOption()]
    @State private var duration = 60
    @StateObject private var executor = Executor()

    var body: some View {
        Section("Title") {
            TextField("Title", text: $title)
        }
        PollOptionsSectionView(header: "Choices",
                               placeholder: "Choice",
                               kind: String(localized: "a choice"),
                               options: $options,
                               maxCount: 5)
        Section {
            Picker("Duration", selection: $duration) {
                ForEach([30, 60, 120, 180, 300, 600], id: \.self) {
                    Text(formatShortDuration(seconds: $0))
                }
            }
        }
        Section {
            HCenter {
                ExecutorView(executor: executor) {
                    CreateButtonView {
                        executor.startProgress()
                        model.createTwitchPoll(title: title.trim(),
                                               choices: pollOptionTitles(options: options),
                                               duration: duration)
                        {
                            executor.completed(result: $0)
                            if $0.isSuccessful() {
                                onCreated()
                            }
                        }
                    }
                    .disabled(!canCreatePoll(title: title, options: options))
                }
            }
        }
    }
}

private struct ActivePollView: View {
    let model: Model
    let poll: TwitchApiPollData
    let onEnded: () -> Void

    private func end(status: TwitchApiPollStatus, onComplete: @escaping (OperationResult) -> Void) {
        model.endTwitchPoll(id: poll.id, status: status) {
            onComplete($0)
            if $0.isSuccessful() {
                onEnded()
            }
        }
    }

    var body: some View {
        Section("Title") {
            Text(poll.title)
        }
        Section("Choices") {
            ForEach(poll.choices) { choice in
                HStack {
                    Text(choice.title)
                    Spacer()
                }
            }
        }
        Section {
            ActionRowView(text: "End poll", image: "stop") {
                end(status: .terminated, onComplete: $0)
            }
            ActionRowView(text: "Archive poll", image: "archivebox") {
                end(status: .archived, onComplete: $0)
            }
        } footer: {
            Text("Ending the poll shows the final results. Archiving it hides them.")
        }
    }
}

private struct PollFormView: View {
    let model: Model
    @State private var loaded = false
    @State private var poll: TwitchApiPollData?
    @StateObject private var executor = Executor()

    private func load() {
        executor.startProgress()
        model.getTwitchPolls {
            switch $0 {
            case let .success(polls):
                poll = polls.first(where: { $0.isActive() })
                executor.completedNoTimer(result: .success(Data()))
            case .authError:
                executor.completedNoTimer(result: .authError)
            case .error:
                executor.completedNoTimer(result: .error)
            }
        }
    }

    private func loadOnce() {
        guard !loaded else {
            return
        }
        loaded = true
        load()
    }

    var body: some View {
        ExecutorView(executor: executor, centerNonContent: true) {
            if let poll {
                ActivePollView(model: model, poll: poll, onEnded: load)
            } else {
                CreatePollView(model: model, onCreated: load)
            }
        }
        .onAppear {
            loadOnce()
        }
    }
}

private struct PollView: View {
    let model: Model

    var body: some View {
        NavigationLinkView(text: "Poll", image: "chart.bar") {
            PollFormView(model: model)
        }
    }
}

private struct CreatePredictionView: View {
    let model: Model
    let onCreated: () -> Void
    @State private var title = ""
    @State private var outcomes = [PollOption(), PollOption()]
    @State private var predictionWindow = 300
    @StateObject private var executor = Executor()

    var body: some View {
        Section("Title") {
            TextField("Title", text: $title)
        }
        PollOptionsSectionView(header: "Outcomes",
                               placeholder: "Outcome",
                               kind: String(localized: "an outcome"),
                               options: $outcomes,
                               maxCount: 10)
        Section {
            Picker("Duration", selection: $predictionWindow) {
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
                        model.createTwitchPrediction(title: title.trim(),
                                                     outcomes: pollOptionTitles(options: outcomes),
                                                     predictionWindow: predictionWindow)
                        {
                            executor.completed(result: $0)
                            if $0.isSuccessful() {
                                onCreated()
                            }
                        }
                    }
                    .disabled(!canCreatePoll(title: title, options: outcomes))
                }
            }
        }
    }
}

private struct PredictionOutcomeView: View {
    let outcome: TwitchApiPredictionOutcome
    let action: (@escaping (OperationResult) -> Void) -> Void
    @StateObject private var executor = Executor()

    var body: some View {
        HStack {
            Text(outcome.title)
            Spacer()
            ExecutorView(executor: executor) {
                BorderlessButtonView(text: "Resolve") {
                    executor.startProgress()
                    action(executor.completed)
                }
            }
        }
    }
}

private struct ActivePredictionView: View {
    let model: Model
    let prediction: TwitchApiPredictionData
    let onEnded: () -> Void

    private func end(status: TwitchApiPredictionStatus,
                     winningOutcomeId: String? = nil,
                     onComplete: @escaping (OperationResult) -> Void)
    {
        model.endTwitchPrediction(id: prediction.id, status: status, winningOutcomeId: winningOutcomeId) {
            onComplete($0)
            if $0.isSuccessful() {
                onEnded()
            }
        }
    }

    var body: some View {
        Section("Title") {
            Text(prediction.title)
        }
        Section {
            ForEach(prediction.outcomes) { outcome in
                PredictionOutcomeView(outcome: outcome) {
                    end(status: .resolved, winningOutcomeId: outcome.id, onComplete: $0)
                }
            }
        } header: {
            Text("Outcomes")
        } footer: {
            Text("Resolve the prediction by selecting the winning outcome.")
        }
        Section {
            if prediction.isActive() {
                ActionRowView(text: "Lock prediction", image: "lock") {
                    end(status: .locked, onComplete: $0)
                }
            }
            ActionRowView(text: "Cancel prediction", image: "xmark") {
                end(status: .canceled, onComplete: $0)
            }
        } footer: {
            Text("Cancelling the prediction refunds all channel points.")
        }
    }
}

private struct PredictionFormView: View {
    let model: Model
    @State private var loaded = false
    @State private var prediction: TwitchApiPredictionData?
    @StateObject private var executor = Executor()

    private func load() {
        executor.startProgress()
        model.getTwitchPredictions {
            switch $0 {
            case let .success(predictions):
                prediction = predictions.first(where: { $0.isActive() || $0.isLocked() })
                executor.completedNoTimer(result: .success(Data()))
            case .authError:
                executor.completedNoTimer(result: .authError)
            case .error:
                executor.completedNoTimer(result: .error)
            }
        }
    }

    private func loadOnce() {
        guard !loaded else {
            return
        }
        loaded = true
        load()
    }

    var body: some View {
        ExecutorView(executor: executor, centerNonContent: true) {
            if let prediction {
                ActivePredictionView(model: model, prediction: prediction, onEnded: load)
            } else {
                CreatePredictionView(model: model, onCreated: load)
            }
        }
        .onAppear {
            loadOnce()
        }
    }
}

private struct PredictionView: View {
    let model: Model

    var body: some View {
        NavigationLinkView(text: "Prediction", image: "sparkles") {
            PredictionFormView(model: model)
        }
    }
}

private struct RaidChannelSearchView: View {
    let model: Model
    @State private var searchText: String = ""
    @State private var channels: [TwitchApiChannel] = []
    @StateObject private var executor = Executor()

    var body: some View {
        Section {
            TextField("Search", text: $searchText)
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                .onChange(of: searchText) { _ in
                    guard !searchText.isEmpty else {
                        channels = []
                        return
                    }
                    executor.startProgress()
                    model.searchTwitchChannels(stream: model.stream, filter: searchText) {
                        switch $0 {
                        case let .success(channels):
                            self.channels = channels.sorted(by: {
                                let searchText = searchText.lowercased()
                                let first = $0.display_name.lowercased()
                                let second = $1.display_name.lowercased()
                                if first.hasPrefix(searchText) {
                                    return true
                                } else if second.hasPrefix(searchText) {
                                    return false
                                } else {
                                    return true
                                }
                            })
                            executor.completedNoTimer(result: .success(Data()))
                        case .authError:
                            executor.completedNoTimer(result: .authError)
                        case .error:
                            executor.completedNoTimer(result: .error)
                        }
                    }
                }
        }
        Section {
            ExecutorView(executor: executor, centerNonContent: true) {
                ForEach(channels) { channel in
                    RaidChannelView(buttonText: "Raid",
                                    channel: channel.display_name,
                                    category: channel.game_name,
                                    title: channel.title,
                                    image: channel.thumbnail_url,
                                    isLive: true,
                                    viewerCount: nil)
                    {
                        model.startRaidTwitchChannel(channelId: channel.id, onComplete: $0)
                    }
                }
            }
        }
    }
}

private struct RaidSuggestion: Identifiable {
    let id: String
    let name: String
    let category: String
    let title: String
    let viewerCount: Int
    var image: String?
}

private func makeRaidSuggestions(streams: [TwitchApiStreamData]) -> [RaidSuggestion] {
    streams.map {
        RaidSuggestion(id: $0.user_id,
                       name: $0.user_name,
                       category: $0.game_name,
                       title: $0.title,
                       viewerCount: $0.viewer_count)
    }
}

private func makeRaidSuggestions(streams: [TwitchApiStreamData],
                                 channels: [SettingsStreamTwitchRaidChannel])
    -> [RaidSuggestion]
{
    var suggestions: [String: RaidSuggestion] = [:]
    for suggestion in makeRaidSuggestions(streams: streams) {
        suggestions[suggestion.id] = suggestion
    }
    return channels.compactMap { suggestions[$0.channelId] }
}

private struct RaidSuggestionsView: View {
    let model: Model
    let suggestions: [RaidSuggestion]

    var body: some View {
        ForEach(suggestions) { suggestion in
            RaidChannelView(buttonText: "Raid",
                            channel: suggestion.name,
                            category: suggestion.category,
                            title: suggestion.title,
                            image: suggestion.image,
                            isLive: true,
                            viewerCount: suggestion.viewerCount)
            {
                model.startRaidTwitchChannel(channelId: suggestion.id, onComplete: $0)
            }
        }
    }
}

private struct RaidHistoryView: View {
    let model: Model
    let title: LocalizedStringKey
    let suggestions: [RaidSuggestion]

    var body: some View {
        Section {
            RaidSuggestionsView(model: model, suggestions: suggestions)
        } header: {
            Text(title)
        }
    }
}

@MainActor
private func fetchRaidSuggestionImages(model: Model,
                                       userIds: [String],
                                       onComplete: @escaping ([String: String]) -> Void)
{
    model.getTwitchUsers(stream: model.stream, userIds: Array(Set(userIds))) { users in
        guard let users else {
            return
        }
        var images: [String: String] = [:]
        for user in users {
            images[user.id] = user.profile_image_url
        }
        onComplete(images)
    }
}

private func setRaidSuggestionImages(_ suggestions: [RaidSuggestion],
                                     images: [String: String]) -> [RaidSuggestion]
{
    suggestions.map {
        var suggestion = $0
        suggestion.image = images[$0.id]
        return suggestion
    }
}

private struct RaidFollowedChannelsView: View {
    let model: Model
    let suggestions: [RaidSuggestion]
    @ObservedObject var executor: Executor

    var body: some View {
        Section {
            ExecutorView(executor: executor, centerNonContent: true) {
                RaidSuggestionsView(model: model, suggestions: suggestions)
            }
        } header: {
            Text("Followed channels")
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
                        Text(formatShortDuration(seconds: $0))
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
            String(localized: "Primary")
        case .blue:
            "🔵"
        case .green:
            "🟢"
        case .orange:
            "🟠"
        case .purple:
            "🟣"
        }
    }
}

private struct SendAnnouncementView: View {
    let model: Model
    @State private var message = ""
    @State private var color: AnnouncementColor = .primary
    @StateObject private var executor = Executor()

    private func canSend() -> Bool {
        !message.trim().isEmpty
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

private struct StartRaidView: View {
    let model: Model
    @State private var raidsSent: [RaidSuggestion] = []
    @State private var raidsReceived: [RaidSuggestion] = []
    @State private var followedChannels: [RaidSuggestion] = []
    @StateObject private var followedChannelsExecutor = Executor()

    private func loadRaidHistory() {
        let sentChannels = model.stream.twitchRaidsSent
        let receivedChannels = model.stream.twitchRaidsReceived
        let userIds = Set(sentChannels.map(\.channelId)).union(receivedChannels.map(\.channelId))
        model.getTwitchStreams(stream: model.stream, userIds: Array(userIds), live: true) { streams in
            guard let streams else {
                return
            }
            raidsSent = makeRaidSuggestions(streams: streams, channels: sentChannels)
            raidsReceived = makeRaidSuggestions(streams: streams, channels: receivedChannels)
            fetchRaidSuggestionImages(model: model,
                                      userIds: raidsSent.map(\.id) + raidsReceived.map(\.id))
            { images in
                raidsSent = setRaidSuggestionImages(raidsSent, images: images)
                raidsReceived = setRaidSuggestionImages(raidsReceived, images: images)
            }
        }
    }

    private func loadFollowedChannels() {
        followedChannelsExecutor.startProgress()
        model.getTwitchFollowedStreams(stream: model.stream) {
            switch $0 {
            case let .success(streams):
                followedChannels = makeRaidSuggestions(streams: streams)
                followedChannelsExecutor.completedNoTimer(result: .success(Data()))
                fetchRaidSuggestionImages(model: model,
                                          userIds: followedChannels.map(\.id))
                { images in
                    followedChannels = setRaidSuggestionImages(followedChannels, images: images)
                }
            case .authError:
                followedChannelsExecutor.completedNoTimer(result: .authError)
            case .error:
                followedChannelsExecutor.completedNoTimer(result: .error)
            }
        }
    }

    var body: some View {
        NavigationLinkView(text: "Raid channel", image: "play.tv") {
            RaidChannelSearchView(model: model)
            RaidHistoryView(model: model, title: "Raided before", suggestions: raidsSent)
            RaidHistoryView(model: model, title: "Raided you", suggestions: raidsReceived)
            RaidFollowedChannelsView(model: model,
                                     suggestions: followedChannels,
                                     executor: followedChannelsExecutor)
        }
        .onAppear {
            loadRaidHistory()
            loadFollowedChannels()
        }
    }
}

struct QuickButtonChatModerationTwitchView: View {
    let model: Model
    @Binding var platform: Platform?

    private func slowModeAction(duration: Int?, onComplete: @escaping (OperationResult) -> Void) {
        model.setTwitchSlowMode(enabled: duration != nil, duration: duration, onComplete: onComplete)
    }

    private func followersOnlyAction(duration: Int?, onComplete: @escaping (OperationResult) -> Void) {
        model.setTwitchFollowersMode(enabled: duration != nil,
                                     duration: (duration ?? 0) / 60,
                                     onComplete: onComplete)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    StartRaidView(model: model)
                    RunCommercialView(model: model)
                    SendAnnouncementView(model: model)
                    PollView(model: model)
                    PredictionView(model: model)
                }
                Section {
                    SlowModeView(durations: [3, 5, 10, 30, 60, 120], action: slowModeAction)
                    FollowersOnlyView(durations: [60, 300, 600, 3600], action: followersOnlyAction)
                    SubscribersOnlyView(action: model.setTwitchSubscribersOnlyMode)
                    EmotesOnlyView(action: model.setTwitchEmoteOnlyMode)
                }
                Section {
                    ForEach(ModActionType.allCases, id: \.self) {
                        UserModerationItemView(model: model, action: $0, platform: .twitch)
                    }
                }
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
