import SwiftUI

struct StreamWizardNetworkSetupDirectSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var ingestError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.directIngest.isEmpty || createStreamWizard.directStreamKey.isEmpty || !ingestError
            .isEmpty
    }

    private func twitchStreamKeyUrl() -> String {
        return "https://dashboard.twitch.tv/u/\(createStreamWizard.twitchChannelName.trim())/settings/stream"
    }

    private func updateIngestError() {
        let url = cleanUrl(url: createStreamWizard.directIngest)
        if url.isEmpty {
            ingestError = ""
        } else {
            ingestError = isValidUrl(url: url, rtmpStreamKeyRequired: false) ?? ""
        }
    }

    var body: some View {
        Form {
            switch createStreamWizard.platform {
            case .twitch:
                Section {
                    TextField("rtmp://arn03.contribute.live-video.net/app", text: $createStreamWizard.directIngest)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onChange(of: createStreamWizard.directIngest) { _ in
                            updateIngestError()
                        }
                } header: {
                    Text("Nearby ingest endpoint")
                } footer: {
                    VStack(alignment: .leading) {
                        FormFieldError(error: ingestError)
                        Text("""
                        Copy from \
                        https://help.twitch.tv/s/twitch-ingest-recommendation. Remove {stream_key}.
                        """)
                    }
                }
                Section {
                    TextField(
                        "live_48950233_okF4f455GRWEF443fFr23GRbt5rEv",
                        text: $createStreamWizard.directStreamKey
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    HStack(spacing: 0) {
                        Text("Copy from ")
                        Link(twitchStreamKeyUrl(), destination: URL(string: twitchStreamKeyUrl())!)
                            .font(.footnote)
                        Text(" (requires login).")
                    }
                }
            case .kick:
                Section {
                    TextField(
                        "rtmps://fa723fc1b171.global-contribute.live-video.net",
                        text: $createStreamWizard.directIngest
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.directIngest) { _ in
                        updateIngestError()
                    }
                } header: {
                    Text("Stream URL")
                } footer: {
                    VStack(alignment: .leading) {
                        FormFieldError(error: ingestError)
                        Text(
                            "Copy from https://kick.com/dashboard/settings/stream (requires login)."
                        )
                    }
                }
                Section {
                    TextField(
                        "sk_us-west-2_okfef49k34k_34g59gGDDHGHSREj754gYJYTJERH",
                        text: $createStreamWizard.directStreamKey
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    Text(
                        "Copy from https://kick.com/dashboard/settings/stream (requires login)."
                    )
                }
            case .youTube:
                Section {
                    TextField(
                        "rtmp://a.rtmp.youtube.com/live2",
                        text: $createStreamWizard.directIngest
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.directIngest) { _ in
                        updateIngestError()
                    }
                } header: {
                    Text("Stream URL")
                } footer: {
                    VStack(alignment: .leading) {
                        FormFieldError(error: ingestError)
                        Text("Copy from https://youtube.com (requires login).")
                    }
                }
                Section {
                    TextField(
                        "4bkf-8d03-g6w3-ekjh-emdc",
                        text: $createStreamWizard.directStreamKey
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    Text("Copy from https://youtube.com (requires login).")
                }
            case .soop:
                Section {
                    TextField(
                        "???",
                        text: $createStreamWizard.directIngest
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.directIngest) { _ in
                        updateIngestError()
                    }
                } header: {
                    Text("Stream URL")
                } footer: {
                    VStack(alignment: .leading) {
                        FormFieldError(error: ingestError)
                        Text("Copy from ??? (requires login).")
                    }
                }
                Section {
                    TextField(
                        "???",
                        text: $createStreamWizard.directStreamKey
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                } header: {
                    Text("Stream key")
                } footer: {
                    Text("Copy from ??? (requires login).")
                }
            case .custom:
                EmptyView()
            case .obs:
                EmptyView()
            }
            Section {
                NavigationLink {
                    StreamWizardChatSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            createStreamWizard.networkSetup = .direct
            updateIngestError()
        }
        .navigationTitle("Direct")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
