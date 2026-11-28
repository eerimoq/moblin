import SwiftUI

struct StreamDoinkSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State private var loggedIn = false
    @State private var streamKey = ""
    @State private var ingest: DoinkApiIngest?
    @State private var info: DoinkApiStream?

    private func credential() -> String? {
        loggedIn ? stream.doinkAccessToken : doinkStreamKey(url: stream.url)
    }

    private func onLoggedIn() {
        loggedIn = true
        loadIngest()
    }

    private func logout() {
        model.doinkLogout(stream: stream)
        loggedIn = false
        loadIngest()
    }

    private func loadIngest() {
        guard let credential = credential() else {
            ingest = nil
            info = nil
            stream.doinkChannelName = ""
            return
        }
        if loggedIn {
            DoinkApi(accessTokenOrStreamKey: credential).getStream {
                if case let .success(info) = $0 {
                    self.info = info
                }
            }
        } else {
            info = nil
        }
        DoinkApi(accessTokenOrStreamKey: credential).getIngest {
            switch $0 {
            case let .success(ingest):
                self.ingest = ingest
                stream.doinkChannelName = ingest.handle
            case .authError:
                if loggedIn {
                    logout()
                }
            case .error:
                break
            }
        }
    }

    private func loadStreamKey(streamKey: String) {
        guard streamKey.count >= 35 else {
            return
        }
        DoinkApi(accessTokenOrStreamKey: streamKey).getIngest {
            guard case let .success(ingest) = $0, streamKey == self.streamKey.trim() else {
                return
            }
            stream.url = ingest.srtlaUrl
            stream.doinkChannelName = ingest.handle
            self.ingest = ingest
            model.reloadStreamIfEnabled(stream: stream)
        }
    }

    var body: some View {
        Form {
            if let credential = credential() {
                DoinkEndStreamView(model: model, api: DoinkApi(accessTokenOrStreamKey: credential))
            }
            Section {
                if loggedIn {
                    TextButtonView("Logout") {
                        logout()
                    }
                } else {
                    TextButtonView("Login") {
                        model.doinkLogin(stream: stream, onComplete: onLoggedIn) {
                            model.showDoinkAuth = true
                        }
                    }
                }
            } footer: {
                if !loggedIn {
                    Text("Optional, but simplifies the setup.")
                }
            }
            if credential() == nil {
                Section {
                    TextField(String("dk_okF4f455GRWEF443fFr23GRbt5rEvokF4f455GRWEF443"), text: $streamKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onChange(of: streamKey) { _ in
                            loadStreamKey(streamKey: streamKey.trim())
                        }
                        .disabled(model.isLive)
                } header: {
                    Text("Stream key")
                }
            }
            if credential() != nil {
                Section {
                    if let ingest {
                        DoinkIngestView(ingest: ingest, url: Binding(get: {
                            stream.url
                        }, set: {
                            stream.url = $0
                            model.reloadStreamIfEnabled(stream: stream)
                        }))
                        .disabled(model.isLive)
                    } else {
                        HStack {
                            Text("Region")
                            Spacer()
                            ProgressView()
                        }
                    }
                    NavigationLink {
                        StreamUrlSettingsView(stream: stream)
                    } label: {
                        TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                    }
                } header: {
                    Text("Ingest")
                }
            }
            if loggedIn {
                DoinkStreamSettingsView(model: model,
                                        stream: stream,
                                        api: DoinkApi(accessTokenOrStreamKey: stream.doinkAccessToken),
                                        info: $info,
                                        reload: loadIngest,
                                        logout: logout)
            }
        }
        .navigationTitle(String("doink.tv"))
        .onAppear {
            loggedIn = !stream.doinkAccessToken.isEmpty
            loadIngest()
        }
    }
}
