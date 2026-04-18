import SwiftUI

struct StreamWizardYouTubeSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @ObservedObject var youTubeStream: SettingsStream

    private func fetchLiveStreams() {
        model.getYouTubeApi(stream: youTubeStream) { youTubeApi in
            youTubeApi?.listLiveStreams {
                switch $0 {
                case let .success(response):
                    if let liveStream = response.items.first {
                        let ingestionInfo = liveStream.cdn.ingestionInfo
                        createStreamWizard.directIngest = ingestionInfo.ingestionAddress
                        createStreamWizard.directStreamKey = ingestionInfo.streamName
                    }
                case .authError, .error:
                    break
                }
            }
        }
    }

    private func fetchChannelHandle() {
        model.getYouTubeApi(stream: youTubeStream) { youTubeApi in
            youTubeApi?.listChannels {
                switch $0 {
                case let .success(response):
                    if let handle = response.items.first?.snippet.customUrl {
                        createStreamWizard.youTubeHandle = handle
                    }
                case .authError, .error:
                    break
                }
            }
        }
    }

    var body: some View {
        Form {
            Section {
                if youTubeStream.youTubeAuthState == nil {
                    TextButtonView("Login") {
                        model.youTubeSignIn(stream: youTubeStream)
                    }
                } else {
                    TextButtonView("Logout") {
                        model.youTubeSignOut(stream: youTubeStream)
                    }
                }
            } footer: {
                Text("Optional, but simplifies the setup.")
            }
            Section {
                TextField(String("@erimo144"), text: $createStreamWizard.youTubeHandle)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Channel handle")
            } footer: {
                Text("Only needed for chat.")
            }
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupSettingsView(
                        model: model,
                        createStreamWizard: createStreamWizard,
                        platform: String(localized: "YouTube")
                    )
                } label: {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            createStreamWizard.platform = .youTube
            createStreamWizard.name = makeUniqueName(name: String(localized: "YouTube"),
                                                     existingNames: model.database.streams)
            createStreamWizard.directIngest = "rtmp://a.rtmp.youtube.com/live2"
            youTubeStream.youTubeAuthState = nil
        }
        .onChange(of: youTubeStream.youTubeAuthState) { authState in
            if authState != nil {
                fetchLiveStreams()
                fetchChannelHandle()
            }
        }
        .navigationTitle("YouTube")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
