import SwiftUI

struct ChzzkChannelIdFooterView: View {
    var body: some View {
        Text("Copy the ID from the end of your CHZZK channel URL, or leave it blank to fill it in at login.")
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
        guard stream.chzzkChannelId != value else {
            return
        }
        stream.chzzkChannelId = value
        if stream.enabled {
            model.chzzkChannelUpdated()
        }
    }

    private var credentials: some View {
        Section {
            Link("CHZZK developer center", destination: URL(string: "https://developers.chzzk.naver.com")!)
            TextField("Client ID", text: $clientId)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            SecureField("Client secret", text: $clientSecret)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            TextButtonView("Save") {
                model.chzzkCredentialsUpdated(clientId: clientId.trim(), clientSecret: clientSecret.trim())
            }
            .disabled(!credentialsChanged || clientId.trim().isEmpty != clientSecret.trim().isEmpty)
        } header: {
            Text("API credentials")
        } footer: {
            VStack(alignment: .leading) {
                Text("Register an app with permission to read user information, chat messages and donations.")
                Text("To send or hide messages, enable chat write permission.")
                Text("To apply or remove restrictions, enable restriction write permission.")
                Text("Login redirect URL")
                Text(verbatim: chzzkRedirectUri)
                    .textSelection(.enabled)
            }
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Channel id"),
                    value: stream.chzzkChannelId,
                    onSubmit: submitChannelId
                )
            } footer: {
                ChzzkChannelIdFooterView()
            }
            if stream.enabled {
                credentials
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
                } footer: {
                    Text("Log in with your streaming account to receive chat messages and donations.")
                }
            } else {
                Section {
                    Text("Select this stream to configure CHZZK login.")
                }
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
