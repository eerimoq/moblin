import SwiftUI

struct VkVideoLiveStreamLiveSettingsView: View {
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
                    model.setVkVideoLiveStreamTitle(stream: stream, title: value) { _ in }
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
            VkVideoLiveCategoryPickerView(stream: stream)
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

private struct VkVideoLiveCategoryPickerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var searchText: String = ""
    @State private var categories: [VkVideoLiveCategory] = []
    @Environment(\.dismiss) var dismiss

    private func categoryButton(category: VkVideoLiveCategory) -> some View {
        Button {
            model.setVkVideoLiveStreamCategory(stream: stream, category: category)
            dismiss()
        } label: {
            HStack {
                if let coverUrl = category.cover_url, let url = URL(string: coverUrl) {
                    CacheAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 40, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(category.title)
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
                            return
                        }
                        model.searchVkVideoLiveCategories(stream: stream, query: searchText) { result in
                            categories = result
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
    }
}

struct VkVideoLiveAlertsSettingsView: View {
    let title: String
    @ObservedObject var alerts: SettingsVkVideoLiveAlerts

    var body: some View {
        Form {
            Section {
                Toggle("Follows", isOn: $alerts.follows)
                Toggle("Subscriptions", isOn: $alerts.subscriptions)
                Toggle("Rewards", isOn: $alerts.rewards)
                Toggle("Raids", isOn: $alerts.raids)
            }
        }
        .navigationTitle(title)
    }
}

@MainActor
func loadVkVideoLiveStreamInfo(model: Model,
                               stream: SettingsStream,
                               loggedIn: Bool,
                               onChange: @escaping (String?, String?) -> Void)
{
    onChange(nil, nil)
    guard loggedIn else {
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        model.getVkVideoLiveStreamInfo(stream: stream) { info in
            onChange(info?.title ?? "", info?.category?.title ?? "")
        }
    }
}

struct StreamVkVideoLiveSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var title: String?
    @State private var category: String?

    private func submitChannelUrl(value: String) {
        stream.vkVideoLiveChannelUrl = value
        if stream.enabled {
            model.vkVideoLiveChannelUrlUpdated()
        }
    }

    private func onLoggedIn() {
        loadStreamInfo()
    }

    private func loadStreamInfo() {
        loadVkVideoLiveStreamInfo(model: model, stream: stream, loggedIn: stream.vkVideoLiveLoggedIn) {
            title = $0
            category = $1
        }
    }

    var body: some View {
        Form {
            Section {
                if !stream.vkVideoLiveLoggedIn {
                    TextButtonView("Login") {
                        model.showVkVideoLiveAuth = true
                        model.vkVideoLiveLogin(stream: stream, onComplete: onLoggedIn)
                    }
                } else {
                    TextButtonView("Logout") {
                        model.vkVideoLiveLogout(stream: stream)
                    }
                }
            } footer: {
                if vkVideoLiveMoblinAppClientId.isEmpty {
                    Text("""
                    No application identifier configured. Register an application at \
                    dev.live.vkvideo.ru and set its identifier in the app source code.
                    """)
                    .foregroundStyle(.red)
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel URL name"),
                    value: stream.vkVideoLiveChannelUrl,
                    onSubmit: submitChannelUrl
                )
            } footer: {
                Text("""
                The name of your channel in its URL, for example "mychannel" for \
                live.vkvideo.ru/mychannel.
                """)
            }
            if stream.vkVideoLiveLoggedIn {
                Section {
                    VkVideoLiveStreamLiveSettingsView(model: model,
                                                      stream: stream,
                                                      title: $title,
                                                      category: $category)
                }
            }
            Section {
                NavigationLink {
                    VkVideoLiveAlertsSettingsView(title: String(localized: "Chat"),
                                                  alerts: stream.vkVideoLiveChatAlerts)
                } label: {
                    Text("Chat")
                }
                NavigationLink {
                    VkVideoLiveAlertsSettingsView(title: String(localized: "Toasts"),
                                                  alerts: stream.vkVideoLiveToastAlerts)
                } label: {
                    Text("Toasts")
                }
            } header: {
                Text("Alerts")
            }
        }
        .navigationTitle("VK Video Live")
        .onAppear {
            loadStreamInfo()
        }
    }
}
