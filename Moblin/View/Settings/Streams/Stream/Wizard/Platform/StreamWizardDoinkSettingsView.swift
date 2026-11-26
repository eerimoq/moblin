import SwiftUI

struct StreamWizardDoinkSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @ObservedObject var stream: SettingsStream
    @State private var streamKey = ""
    @State private var ingest: DoinkApiIngest?

    private func loadIngest(credential: String) {
        ingest = nil
        guard !credential.isEmpty else {
            return
        }
        DoinkApi(accessTokenOrStreamKey: credential).getIngest {
            guard case let .success(ingest) = $0,
                  credential == streamKey.trim() || credential == stream.doinkAccessToken
            else {
                return
            }
            stream.url = ingest.srtlaUrl
            self.ingest = ingest
        }
    }

    private func onLoginComplete() {
        loadIngest(credential: stream.doinkAccessToken)
    }

    var body: some View {
        Form {
            Section {
                if stream.doinkAccessToken.isEmpty {
                    TextButtonView("Login") {
                        model.doinkLogin(stream: stream, onComplete: onLoginComplete) {
                            createStreamWizard.showDoinkAuth = true
                        }
                    }
                } else {
                    TextButtonView("Logout") {
                        model.doinkLogout(stream: stream)
                        ingest = nil
                    }
                }
            } footer: {
                Text("Optional, but simplifies the setup.")
            }
            if stream.doinkAccessToken.isEmpty {
                Section {
                    TextField(String("dk_okF4f455GRWEF443fFr23GRbt5rEvokF4f455GRWEF443"), text: $streamKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onChange(of: streamKey) { _ in
                            loadIngest(credential: streamKey.trim().count >= 35 ? streamKey.trim() : "")
                        }
                } header: {
                    Text("Stream key")
                }
            }
            if let ingest {
                Section {
                    Text(ingest.handle)
                } header: {
                    Text("Channel name")
                }
                Section {
                    DoinkIngestView(ingest: ingest, url: $stream.url)
                    TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                }
            }
            Section {
                NavigationLink {
                    StreamWizardGeneralSettingsView(model: model, createStreamWizard: createStreamWizard)
                } label: {
                    WizardNextButtonView()
                }
                .disabled(ingest == nil)
            }
        }
        .sheet(isPresented: $createStreamWizard.showDoinkAuth) {
            DoinkLoginView(model: model, presenting: $createStreamWizard.showDoinkAuth)
        }
        .onAppear {
            createStreamWizard.platform = .doink
            createStreamWizard.networkSetup = .direct
            createStreamWizard.name = makeUniqueName(name: String("doink.tv"),
                                                     existingNames: model.database.streams)
            if ingest == nil {
                loadIngest(credential: stream.doinkAccessToken)
            }
        }
        .navigationTitle(String("doink.tv"))
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
