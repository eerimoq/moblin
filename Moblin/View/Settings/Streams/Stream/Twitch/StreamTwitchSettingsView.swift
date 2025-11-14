import SwiftUI

struct TwitchStreamLiveSettingsView: View {
    let model: Model
    var stream: SettingsStream
    @Binding var title: String?
    @Binding var category: String?

    var body: some View {
        NavigationLink {
            TextEditView(
                title: String(localized: "Title"),
                value: title ?? "",
                onSubmit: { value in
                    model.setTwitchStreamTitle(stream: stream, title: value)
                }
            )
        } label: {
            HStack {
                Text("Title")
                Spacer()
                if let title {
                    Text(title)
                        .foregroundStyle(.gray)
                } else {
                    ProgressView()
                }
            }
        }
        NavigationLink {
            TwitchCategoryPickerView(stream: stream)
        } label: {
            HStack {
                Text("Category")
                Spacer()
                if let category {
                    Text(category)
                        .foregroundStyle(.gray)
                } else {
                    ProgressView()
                }
            }
        }
    }
}

private struct TwitchCategoryPickerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var searchText: String = ""
    @State private var categories: [TwitchApiGameData] = []
    @Environment(\.dismiss) var dismiss

    private func fetchDefaultCategories() {
        let categoryNames = ["IRL", "Just Chatting", "Food & Drink"]
        model.fetchTwitchGames(stream: stream, names: categoryNames) { games in
            DispatchQueue.main.async {
                self.categories = games ?? []
            }
        }
    }

    private func categoryButton(category: TwitchApiGameData) -> some View {
        Button {
            model.setTwitchStreamCategory(stream: stream, categoryId: category.id)
            dismiss()
        } label: {
            HStack {
                if let boxArtUrl = category.boxArtUrl(width: 80, height: 100), let url = URL(string: boxArtUrl) {
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 40, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(category.name)
            }
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Search", text: $searchText)
                    .autocorrectionDisabled(true)
                    .onChange(of: searchText) { _ in
                        guard !searchText.isEmpty else {
                            return
                        }
                        model.searchTwitchCategories(stream: stream, filter: searchText) { categories in
                            DispatchQueue.main.async {
                                self.categories = categories ?? []
                            }
                        }
                    }
            }
            Section {
                ForEach(categories) { category in
                    categoryButton(category: category)
                }
            }
        }
        .navigationTitle("Category")
        .onAppear {
            fetchDefaultCategories()
        }
    }
}

struct TwitchAlertsSettingsView: View {
    let title: String
    @ObservedObject var alerts: SettingsTwitchAlerts

    var body: some View {
        Form {
            Section {
                Toggle("Follows", isOn: $alerts.follows)
                Toggle("Subscriptions", isOn: $alerts.subscriptions)
                Toggle("Gift subscriptions", isOn: $alerts.giftSubscriptions)
                Toggle("Resubscriptions", isOn: $alerts.resubscriptions)
                Toggle("Rewards", isOn: $alerts.rewards)
                Toggle("Raids", isOn: $alerts.raids)
                Toggle("Bits", isOn: $alerts.cheers)
                TextEditNavigationView(
                    title: String(localized: "Minimum bits"),
                    value: String(alerts.minimumCheerBits),
                    onSubmit: {
                        alerts.minimumCheerBits = Int($0) ?? 0
                    }
                )
            }
        }
        .navigationTitle(title)
    }
}

func loadTwitchStreamInfo(model: Model,
                          stream: SettingsStream,
                          loggedIn: Bool,
                          onChange: @escaping (String?, String?) -> Void)
{
    onChange(nil, nil)
    guard loggedIn else {
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        model.getTwitchChannelInformation(stream: stream) { info in
            DispatchQueue.main.async {
                onChange(info.title, info.game_name)
            }
        }
    }
}

struct StreamTwitchSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var loggedIn: Bool
    @State private var title: String?
    @State private var category: String?

    private func submitChannelName(value: String) {
        stream.twitchChannelName = value
        if stream.enabled {
            model.twitchChannelNameUpdated()
        }
    }

    private func submitChannelId(value: String) {
        stream.twitchChannelId = value
        if stream.enabled {
            model.twitchChannelIdUpdated()
        }
    }

    private func onLoggedIn() {
        loggedIn = true
        loadStreamInfo()
    }

    private func loadStreamInfo() {
        loadTwitchStreamInfo(model: model, stream: stream, loggedIn: loggedIn) {
            title = $0
            category = $1
        }
    }

    var body: some View {
        Form {
            Section {
                if !loggedIn {
                    TextButtonView("Login") {
                        model.showTwitchAuth = true
                        model.twitchLogin(stream: stream, onComplete: onLoggedIn)
                    }
                } else {
                    TextButtonView("Logout") {
                        model.twitchLogout(stream: stream)
                        loggedIn = false
                    }
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.twitchChannelName,
                    onSubmit: submitChannelName,
                    capitalize: true
                )
            } footer: {
                Text("The name of your channel.")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel id"),
                    value: stream.twitchChannelId,
                    onSubmit: submitChannelId
                )
            }
            if loggedIn {
                Section {
                    TwitchStreamLiveSettingsView(model: model,
                                                 stream: stream,
                                                 title: $title,
                                                 category: $category)
                }
            }
            Section {
                NavigationLink {
                    TwitchAlertsSettingsView(title: String(localized: "Chat"), alerts: stream.twitchChatAlerts)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    TwitchAlertsSettingsView(title: String(localized: "Toasts"), alerts: stream.twitchToastAlerts)
                } label: {
                    Text("Toasts")
                }
            } header: {
                Text("Alerts")
            }
        }
        .navigationTitle("Twitch")
        .onAppear {
            loadStreamInfo()
        }
    }
}
