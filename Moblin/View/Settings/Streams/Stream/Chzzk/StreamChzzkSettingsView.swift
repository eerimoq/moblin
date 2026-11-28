import SwiftUI

struct ChzzkChannelIdFooterView: View {
    var body: some View {
        Text("Leave this blank to use the channel you log in with.")
    }
}

struct ChzzkSetupGuideLink: View {
    var body: some View {
        NavigationLink("CHZZK setup guide") {
            Form {
                Section {
                    Link(destination: URL(string: "https://developers.chzzk.naver.com")!) {
                        HStack {
                            Text("CHZZK developer center")
                            Image(systemName: "arrow.up.right")
                                .accessibilityHidden(true)
                        }
                    }
                    Text("1. In My Services → Register application, enter an ID in English and an app name.")
                    Text("2. Paste the address below into the Login redirect URL field.")
                    ViewThatFits(in: .horizontal) {
                        HStack { redirectAddress }
                        VStack(alignment: .leading) { redirectAddress }
                    }
                    Text("""
                    3. Under API Scopes, select **user read, chat read, chat write, restriction write, \
                    donation read, subscription read, and broadcast settings read and write**, then tap Save → Register.
                    """)
                }
                Section {
                    Text("""
                    1. Open your registered app in the application list. Copy its Client ID and Client Secret \
                    into the matching fields in Moblin.
                    """)
                    Text("2. Tap Save → Login and approve access.")
                } header: {
                    Text("Connect account")
                } footer: {
                    Text("If you change permissions, log out and log in again.")
                        .italic()
                }
            }
            .navigationTitle("CHZZK setup guide")
        }
    }

    @ViewBuilder private var redirectAddress: some View {
        Text(verbatim: chzzkRedirectUri)
            .textSelection(.enabled)
        Button {
            UIPasteboard.general.string = chzzkRedirectUri
        } label: {
            Text("Copy address").bold()
        }
        .buttonStyle(.borderless)
    }
}

private struct ChzzkCategoryPicker: View {
    let api: ChzzkApi
    let select: (ChzzkLiveCategory) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [ChzzkLiveCategory] = []
    @State private var error: String?

    var body: some View {
        Form {
            TextField("Search", text: $query)
                .autocorrectionDisabled(true)
            if let error {
                Text(error)
            }
            ForEach(results, id: \.categoryId) { category in
                Button(category.categoryValue) {
                    select(category)
                    dismiss()
                }
            }
        }
        .navigationTitle("Category")
        .task(id: query) {
            results = []
            error = nil
            guard !query.trim().isEmpty else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))
                let matches = try await api.categories(query: query.trim())
                try Task.checkCancellation()
                results = matches
                if matches.isEmpty {
                    error = String(localized: "No categories found.")
                }
            } catch {
                if !Task.isCancelled {
                    self.error = String(localized: "Could not search CHZZK categories.")
                }
            }
        }
    }
}

struct ChzzkStreamLiveSettingsView: View {
    let model: Model
    let streamId: UUID
    let channelId: String
    @State private var settings: ChzzkLiveSettings?
    @State private var error: String?
    @State private var saving = false

    private func showError(_ failure: Error, writing: Bool) {
        if case ChzzkApiError.status(403) = failure {
            error = writing ?
                String(localized: "Enable the CHZZK broadcast settings write permission and log in again.") :
                String(localized: "Enable the CHZZK broadcast settings read permission and log in again.")
        } else if !(failure is CancellationError), !Task.isCancelled {
            error = String(localized: "Could not load or save CHZZK broadcast settings.")
        }
    }

    private func load() async {
        do {
            let current = try await model
                .withChzzkLiveSettings(streamId: streamId, channelId: channelId) { api, token in
                    try await api.liveSettings(token: token)
                }
            try Task.checkCancellation()
            settings = current
            error = nil
        } catch { showError(error, writing: false) }
    }

    private func save(_ update: ChzzkLiveUpdate) {
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                try await model
                    .withChzzkLiveSettings(streamId: streamId, channelId: channelId) { api, token in
                        try await api.updateLiveSettings(update, token: token)
                    }
                await load()
            } catch { showError(error, writing: true) }
        }
    }

    var body: some View {
        Group {
            if let settings {
                NavigationLink {
                    TextEditView(title: String(localized: "Title"), value: settings.defaultLiveTitle,
                                 onChange: {
                                     $0.trim().isEmpty ? String(localized: "Enter a broadcast title.") : nil
                                 },
                                 onSubmit: {
                                     if !$0.isEmpty {
                                         save(.title($0))
                                     }
                                 })
                } label: {
                    TextItemView(name: String(localized: "Title"), value: settings.defaultLiveTitle)
                }
                if let api = model.chzzkApi {
                    NavigationLink {
                        ChzzkCategoryPicker(api: api) { save(.category($0)) }
                    } label: {
                        TextItemView(
                            name: String(localized: "Category"),
                            value: settings.category?.categoryValue ?? ""
                        )
                    }
                }
            } else if error == nil {
                ProgressView()
            }
            if let error {
                Text(error)
                Button("Retry") { Task { await load() } }
            }
        }
        .disabled(saving)
        .task { await load() }
    }
}

struct StreamChzzkSettingsView: View {
    @ObservedObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var clientId = ""
    @State private var clientSecret = ""

    private var credentialsChanged: Bool {
        clientId.trim() != model.chzzkClientId || clientSecret.trim() != model.chzzkClientSecret
    }

    private func submitChannelId(value: String) {
        guard stream.setChzzkChannelId(
            value,
            signedInChannelId: stream.enabled ? model.chzzkAuthorizedChannelId : nil
        ) else {
            return
        }
        if stream.enabled {
            model.chzzkChannelUpdated()
        }
    }

    private var credentials: some View {
        Section {
            TextField("Client ID", text: $clientId)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            SecureField("Client Secret", text: $clientSecret)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            TextButtonView("Save") {
                model.chzzkCredentialsUpdated(clientId: clientId.trim(), clientSecret: clientSecret.trim())
            }
            .disabled(!credentialsChanged || clientId.trim().isEmpty != clientSecret.trim().isEmpty)
        } header: {
            Text("API credentials")
        }
    }

    var body: some View {
        Form {
            Section {
                ChzzkSetupGuideLink()
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel id"),
                    value: stream.chzzkChannelId,
                    onChange: { value in
                        value.isEmpty || isValidChzzkChannelId(value) ? nil :
                            String(localized: "Enter a 32-character hexadecimal channel ID.")
                    },
                    onSubmit: submitChannelId,
                    valueFormat: { _ in stream.chzzkChannelId }
                )
            } footer: {
                ChzzkChannelIdFooterView()
            }
            if stream.enabled {
                credentials
                if model.chzzkLoggedIn {
                    Section {
                        ChzzkStreamLiveSettingsView(
                            model: model,
                            streamId: stream.id,
                            channelId: stream.chzzkChannelId
                        )
                        .id(stream.chzzkChannelId)
                    }
                }
                Section {
                    if model.chzzkLoggedIn {
                        TextButtonView("Logout") {
                            model.chzzkSignOut()
                        }
                    } else {
                        TextButtonView("Login") {
                            model.chzzkSignIn()
                        }
                        .disabled(credentialsChanged || model.chzzkClientId.isEmpty
                            || model.chzzkClientSecret.isEmpty)
                    }
                }
            } else {
                Section {
                    Text("Select this stream to configure CHZZK login.")
                }
            }
            Section {
                NavigationLink("Chat") {
                    Form {
                        Toggle("Chat donations", isOn: $stream.chzzkChatDonations)
                        Toggle("Video donations", isOn: $stream.chzzkChatVideoDonations)
                        Toggle("Subscriptions", isOn: $stream.chzzkChatSubscriptions)
                    }
                    .navigationTitle("Chat")
                }
                NavigationLink("Toasts") {
                    Form {
                        Toggle("Chat donations", isOn: $stream.chzzkToastDonations)
                        Toggle("Video donations", isOn: $stream.chzzkToastVideoDonations)
                        Toggle("Subscriptions", isOn: $stream.chzzkToastSubscriptions)
                    }
                    .navigationTitle("Toasts")
                }
            } header: {
                Text("Alerts")
            }
        }
        .navigationTitle("CHZZK")
        .onAppear {
            clientId = model.chzzkClientId
            clientSecret = model.chzzkClientSecret
        }
        .sheet(isPresented: $model.chzzkPresentingLogin) {
            ChzzkLoginView(model: model)
        }
    }
}
