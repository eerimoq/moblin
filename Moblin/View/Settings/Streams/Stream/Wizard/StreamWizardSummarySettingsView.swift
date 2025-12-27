import SwiftUI

private struct PlatformView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        switch createStreamWizard.platform {
        case .twitch:
            Section {
                TextValueLocalizedView(name: "Channel name", value: createStreamWizard.twitchChannelName)
                TextValueLocalizedView(name: "Channel id", value: createStreamWizard.twitchChannelId)
            } header: {
                Text("Twitch")
            }
        case .kick:
            Section {
                TextValueLocalizedView(name: "Channel name", value: createStreamWizard.kickChannelName)
            } header: {
                Text("Kick")
            }
        case .youTube:
            Section {
                TextValueLocalizedView(name: "Channel handle", value: createStreamWizard.youTubeHandle)
            } header: {
                Text("YouTube")
            }
        case .soop:
            Section {
                TextValueLocalizedView(name: "Channel name", value: createStreamWizard.soopChannelName)
                TextValueLocalizedView(name: "Video id", value: createStreamWizard.soopStreamId)
            } header: {
                Text("SOOP")
            }
        case .custom:
            EmptyView()
        case .obs:
            EmptyView()
        }
    }
}

private struct NetworkSetupDirectView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        switch createStreamWizard.platform {
        case .twitch:
            TextValueLocalizedView(name: "Nearby ingest endpoint", value: createStreamWizard.directIngest)
            TextValueLocalizedView(name: "Stream key", value: createStreamWizard.directStreamKey)
        case .kick:
            TextValueLocalizedView(name: "Stream URL", value: createStreamWizard.directIngest)
            TextValueLocalizedView(name: "Stream key", value: createStreamWizard.directStreamKey)
        case .youTube:
            TextValueLocalizedView(name: "Stream URL", value: createStreamWizard.directIngest)
            TextValueLocalizedView(name: "Stream key", value: createStreamWizard.directStreamKey)
        case .soop:
            TextValueLocalizedView(name: "Stream URL", value: createStreamWizard.directIngest)
            TextValueLocalizedView(name: "Stream key", value: createStreamWizard.directStreamKey)
        case .custom:
            EmptyView()
        case .obs:
            EmptyView()
        }
    }
}

private struct NetworkSetupView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        if createStreamWizard.networkSetup == .obs {
            Section {
                TextValueLocalizedView(
                    name: "IP address or domain name",
                    value: createStreamWizard.obsAddress
                )
                TextValueLocalizedView(name: "Port", value: createStreamWizard.obsPort)
            } header: {
                Text("OBS")
            }
        } else if createStreamWizard.networkSetup == .belaboxCloudObs {
            Section {
                TextValueLocalizedView(name: "Ingest URL", value: createStreamWizard.belaboxUrl)
            } header: {
                Text("BELABOX cloud")
            }
        } else if createStreamWizard.networkSetup == .direct {
            Section {
                NetworkSetupDirectView(createStreamWizard: createStreamWizard)
            } header: {
                Text("Direct")
            }
        }
    }
}

struct StreamWizardSummarySettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            PlatformView(createStreamWizard: createStreamWizard)
            NetworkSetupView(createStreamWizard: createStreamWizard)
            if createStreamWizard.platform == .custom || createStreamWizard.networkSetup == .myServers {
                if createStreamWizard.customProtocol == .srt {
                    Section {
                        TextValueLocalizedView(name: "URL", value: createStreamWizard.customSrtUrl)
                        TextValueLocalizedView(name: "Stream id", value: createStreamWizard.customSrtStreamId)
                    } header: {
                        Text("SRT(LA)")
                    }
                } else if createStreamWizard.customProtocol == .rtmp {
                    Section {
                        TextValueLocalizedView(name: "URL", value: createStreamWizard.customRtmpUrl)
                        TextValueLocalizedView(
                            name: "Stream key",
                            value: createStreamWizard.customRtmpStreamKey
                        )
                    } header: {
                        Text("RTMP(S)")
                    }
                }
            }
            if createStreamWizard.platform != .custom {
                if createStreamWizard.networkSetup != .direct {
                    if createStreamWizard.obsRemoteControlEnabled {
                        Section {
                            TextValueLocalizedView(name: "URL", value: createStreamWizard.obsRemoteControlUrl)
                            TextValueLocalizedView(
                                name: "Password",
                                value: createStreamWizard.obsRemoteControlPassword
                            )
                            TextValueLocalizedView(
                                name: "BRB scene",
                                value: createStreamWizard.obsRemoteControlBrbScene
                            )
                            TextValueLocalizedView(
                                name: "Source name",
                                value: createStreamWizard.obsRemoteControlSourceName
                            )
                        } header: {
                            Text("OBS remote control")
                        }
                    }
                }
                Section {
                    TextValueLocalizedView(name: "BTTV emotes", value: yesOrNo(createStreamWizard.chatBttv))
                    TextValueLocalizedView(name: "FFZ emotes", value: yesOrNo(createStreamWizard.chatFfz))
                    TextValueLocalizedView(name: "7TV emotes", value: yesOrNo(createStreamWizard.chatSeventv))
                } header: {
                    Text("Chat")
                }
            }
            Section {
                TextField("Name", text: $createStreamWizard.name)
            } header: {
                Text("Stream name")
                    .disableAutocorrection(true)
            }
            Section {
                TextButtonView("Create") {
                    model.createStreamFromWizard()
                    createStreamWizard.presenting = false
                    createStreamWizard.presentingSetup = false
                }
                .disabled(createStreamWizard.name.isEmpty)
            }
        }
        .navigationTitle("Summary and stream name")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
