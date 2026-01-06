import SwiftUI

private struct AuthenticationView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var presentingWebView = false
    let onLoggedIn: () -> Void

    var body: some View {
        Section {
            if !stream.kickLoggedIn {
                TextButtonView("Login") {
                    presentingWebView = true
                    model.kickLogin(stream: stream) {
                        onLoggedIn()
                    }
                }
            } else {
                TextButtonView("Logout") {
                    model.kickLogout(stream: stream)
                }
            }
        }
        .sheet(isPresented: $presentingWebView) {
            KickLoginView(presenting: $presentingWebView) { accessToken in
                model.kickAuthOnComplete?(accessToken)
            }
        }
    }
}

private struct KickCategoryPickerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var searchText: String = ""
    @State private var categories: [KickCategory] = []
    @Environment(\.dismiss) var dismiss

    private func fetchDefaultCategories() {
        let categoryNames = ["IRL", "Just Chatting", "Slots & Casino"]
        for categoryName in categoryNames {
            model.fetchKickCategories(query: categoryName) { result in
                if let category = result?.first {
                    self.categories.append(category)
                }
            }
        }
    }

    private func categoryButton(category: KickCategory) -> some View {
        Button {
            guard let categoryId = Int(category.id) else {
                return
            }
            model.setKickStreamCategory(stream: stream, categoryId: categoryId)
            dismiss()
        } label: {
            HStack {
                if let imageUrl = category.src, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 40, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            categories = []
                            fetchDefaultCategories()
                            return
                        }
                        model.searchKickCategories(stream: stream, query: searchText) { result in
                            self.categories = result ?? []
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

struct KickStreamLiveSettingsView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @Binding var title: String?
    @Binding var category: String?

    var body: some View {
        NavigationLink {
            TextEditView(
                title: String(localized: "Title"),
                value: title ?? "",
                onSubmit: { value in
                    model.setKickStreamTitle(stream: stream, title: value) { _ in }
                }
            )
        } label: {
            HStack {
                Text("Title")
                Spacer()
                if let title {
                    GrayTextView(text: title)
                } else {
                    ProgressView()
                }
            }
        }
        NavigationLink {
            KickCategoryPickerView(stream: stream)
        } label: {
            HStack {
                Text("Category")
                Spacer()
                if let category {
                    GrayTextView(text: category)
                } else {
                    ProgressView()
                }
            }
        }
    }
}

struct KickAlertsSettingsView: View {
    let title: String
    @ObservedObject var alerts: SettingsKickAlerts
    let showBans: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Subscriptions", isOn: $alerts.subscriptions)
                Toggle("Gift subscriptions", isOn: $alerts.giftedSubscriptions)
                Toggle("Rewards", isOn: $alerts.rewards)
                Toggle("Hosts", isOn: $alerts.hosts)
                if showBans {
                    Toggle("Bans and timeouts", isOn: $alerts.bans)
                }
                Toggle("Kicks", isOn: $alerts.kicks)
                TextEditNavigationView(
                    title: String(localized: "Minimum kicks"),
                    value: String(alerts.minimumKicks),
                    onSubmit: {
                        alerts.minimumKicks = Int($0) ?? 0
                    }
                )
            }
        }
        .navigationTitle(title)
    }
}

func loadKickStreamInfo(model: Model,
                        stream: SettingsStream,
                        loggedIn: Bool,
                        onChange: @escaping (String?, String?) -> Void)
{
    onChange(nil, nil)
    guard loggedIn else {
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        model.getKickStreamInfo(stream: stream) { result in
            switch result {
            case let .success(info):
                onChange(info.title, info.categoryName)
            default:
                onChange(nil, nil)
            }
        }
    }
}

struct StreamKickSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var fetchingChannelInfo: Bool = false
    @State private var fetchChannelInfoFailed: Bool = false
    @State private var title: String?
    @State private var category: String?

    private func fetchChannelInfo() {
        fetchingChannelInfo = true
        fetchChannelInfoFailed = false
        getKickChannelInfo(channelName: stream.kickChannelName) { channelInfo in
            fetchingChannelInfo = false
            if let channelInfo {
                fetchChannelInfoFailed = false
                stream.kickChannelId = String(channelInfo.chatroom.id)
                stream.kickSlug = channelInfo.slug
                stream.kickChatroomChannelId = String(channelInfo.chatroom.channel_id)
                loadStreamInfo()
            } else {
                fetchChannelInfoFailed = true
            }
            reloadConnectionsIfEnabled()
        }
    }

    private func resetSettings() {
        stream.kickChannelName = ""
        stream.kickChannelId = nil
        stream.kickSlug = nil
        stream.kickChatroomChannelId = nil
    }

    private func submitChannelName(value: String) {
        resetSettings()
        stream.kickChannelName = value
        fetchChannelInfo()
        if stream.enabled, stream.kickChannelName.isEmpty {
            model.kickChannelNameUpdated()
        }
    }

    private func onLoggedIn() {
        getKickUser(accessToken: stream.kickAccessToken) { data in
            self.handleUser(data: data)
        }
    }

    private func handleUser(data: KickUser?) {
        if let data {
            resetSettings()
            stream.kickChannelName = data.username
            fetchChannelInfo()
        } else {
            reloadConnectionsIfEnabled()
        }
    }

    private func reloadConnectionsIfEnabled() {
        if stream.enabled {
            model.kickAccessTokenUpdated()
        }
    }

    private func loadStreamInfo() {
        loadKickStreamInfo(model: model, stream: stream, loggedIn: stream.kickLoggedIn) {
            title = $0
            category = $1
        }
    }

    var body: some View {
        Form {
            AuthenticationView(stream: stream, onLoggedIn: onLoggedIn)
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel name"),
                    value: stream.kickChannelName,
                    onChange: { _ in nil },
                    onSubmit: submitChannelName
                )
            } footer: {
                if fetchingChannelInfo {
                    Text("Fetching channel info...")
                } else if fetchChannelInfoFailed {
                    Text("Channel not found on kick.com.")
                        .foregroundStyle(.red)
                }
            }
            if stream.kickLoggedIn {
                Section {
                    KickStreamLiveSettingsView(model: model,
                                               stream: stream,
                                               title: $title,
                                               category: $category)
                }
            }
            Section {
                NavigationLink {
                    KickAlertsSettingsView(title: String(localized: "Chat"),
                                           alerts: stream.kickChatAlerts,
                                           showBans: true)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    KickAlertsSettingsView(title: String(localized: "Toasts"),
                                           alerts: stream.kickToastAlerts,
                                           showBans: false)
                } label: {
                    Text("Toasts")
                }
            } header: {
                Text("Alerts")
            }
        }
        .onAppear {
            loadStreamInfo()
        }
        .navigationTitle("Kick")
    }
}
