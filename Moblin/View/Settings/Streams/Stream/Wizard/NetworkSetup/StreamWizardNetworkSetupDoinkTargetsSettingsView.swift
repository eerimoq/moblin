import SwiftUI

struct StreamWizardNetworkSetupDoinkTargetsSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    let platform: String
    @State private var info: DoinkApiStream?

    private func accessToken() -> String {
        createStreamWizard.doinkStream.doinkAccessToken
    }

    private func load() {
        guard !accessToken().isEmpty else {
            return
        }
        DoinkApi(accessTokenOrStreamKey: accessToken()).getStream {
            if case let .success(info) = $0 {
                self.info = info
            }
        }
    }

    private func targetPlatform() -> String {
        switch createStreamWizard.platform {
        case .twitch:
            "twitch"
        case .kick:
            "kick"
        default:
            "custom"
        }
    }

    private func targetKey() -> String {
        createStreamWizard.platform == .twitch ? createStreamWizard.directStreamKey : ""
    }

    var body: some View {
        Form {
            if accessToken().isEmpty {
                Section {
                    Text(
                        "Add \(platform) as a destination on doink.tv, or go back and log in to add it here."
                    )
                }
            } else {
                Section {
                    Text("doink.tv sends your stream to these destinations. Add \(platform) to stream there.")
                }
                DoinkTargetsView(api: DoinkApi(accessTokenOrStreamKey: accessToken()),
                                 targets: info?.targets ?? [],
                                 targetLimit: info?.targetLimit ?? 0,
                                 platform: targetPlatform(),
                                 key: targetKey())
                { result in
                    if case let .error(message) = result {
                        model.makeErrorToast(title: message ?? String(localized: "Failed to update doink"))
                    }
                    load()
                }
            }
            Section {
                NavigationLink {
                    StreamWizardGeneralSettingsView(model: model, createStreamWizard: createStreamWizard)
                } label: {
                    WizardNextButtonView()
                }
            }
        }
        .onAppear {
            load()
        }
        .navigationTitle("Multi streaming")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
