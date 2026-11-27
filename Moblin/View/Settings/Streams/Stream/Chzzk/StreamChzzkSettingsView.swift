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
                Section("Stream URL and key") {
                    Text("Copy the stream URL and stream key from Settings in CHZZK Studio on your computer.")
                    Text(
                        "In the stream wizard, choose CHZZK, then Moblin → CHZZK, and paste the URL and key."
                    )
                }
                Section("Register an application") {
                    Link(
                        "CHZZK developer center",
                        destination: URL(string: "https://developers.chzzk.naver.com")!
                    )
                    Text("Sign in to the developer center and open My Services → Register application.")
                    Text("Choose an application ID and name. Check availability for each one.")
                    Text("Copy the URL below and paste it into the Login redirect URL field.")
                    Text(verbatim: chzzkRedirectUri)
                        .textSelection(.enabled)
                    Button("Copy login redirect URL") {
                        UIPasteboard.general.string = chzzkRedirectUri
                    }
                }
                Section("API permissions") {
                    Text(
                        "Under API Scopes, select read access for user info, chat messages, and donations."
                    )
                    Text("To send chat, post bot replies, or hide messages, also choose chat write.")
                    Text("To apply or remove restrictions, enable restriction write permission.")
                    Text("Tap Save in the permissions window, then Register on the application form.")
                }
                Section("Connect your CHZZK account") {
                    Text(
                        "Open your app in the list. Copy the Client ID, then tap Show to copy the Client Secret."
                    )
                    Text("In the active stream’s settings, open CHZZK under Streaming platforms.")
                    Text("Paste both values into the matching fields in Moblin and tap Save.")
                    Text("Tap Login, sign in with the account that owns the channel, and approve access.")
                    Text(
                        "If you change the app permissions later, log out of CHZZK in Moblin and log in again."
                    )
                }
            }
            .navigationTitle("CHZZK setup guide")
        }
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
