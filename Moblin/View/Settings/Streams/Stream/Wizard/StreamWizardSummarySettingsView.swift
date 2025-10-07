import SwiftUI

private struct PlatformView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        switch createStreamWizard.platform {
        case .twitch:
            Section {
                TextValueView(
                    name: String(localized: "Channel name"),
                    value: createStreamWizard.twitchChannelName
                )
                TextValueView(name: String(localized: "Channel id"), value: createStreamWizard.twitchChannelId)
            } header: {
                Text("Twitch")
            }
        case .kick:
            Section {
                TextValueView(name: String(localized: "Channel name"), value: createStreamWizard.kickChannelName)
            } header: {
                Text("Kick")
            }
        case .youTube:
            Section {
                TextValueView(name: String(localized: "Channel handle"), value: createStreamWizard.youTubeHandle)
            } header: {
                Text("YouTube")
            }
        case .soop:
            Section {
                TextValueView(
                    name: String(localized: "Channel name"),
                    value: createStreamWizard.soopChannelName
                )
                TextValueView(name: String(localized: "Video id"), value: createStreamWizard.soopStreamId)
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
            TextValueView(
                name: String(localized: "Nearby ingest endpoint"),
                value: createStreamWizard.directIngest
            )
            TextValueView(
                name: String(localized: "Stream key"),
                value: createStreamWizard.directStreamKey
            )
        case .kick:
            TextValueView(name: String(localized: "Stream URL"), value: createStreamWizard.directIngest)
            TextValueView(
                name: String(localized: "Stream key"),
                value: createStreamWizard.directStreamKey
            )
        case .youTube:
            TextValueView(name: String(localized: "Stream URL"), value: createStreamWizard.directIngest)
            TextValueView(
                name: String(localized: "Stream key"),
                value: createStreamWizard.directStreamKey
            )
        case .soop:
            TextValueView(name: String(localized: "Stream URL"), value: createStreamWizard.directIngest)
            TextValueView(
                name: String(localized: "Stream key"),
                value: createStreamWizard.directStreamKey
            )
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
                TextValueView(
                    name: String(localized: "IP address or domain name"),
                    value: createStreamWizard.obsAddress
                )
                TextValueView(name: String(localized: "Port"), value: createStreamWizard.obsPort)
            } header: {
                Text("OBS")
            }
        } else if createStreamWizard.networkSetup == .belaboxCloudObs {
            Section {
                TextValueView(name: String(localized: "Ingest URL"), value: createStreamWizard.belaboxUrl)
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
                        TextValueView(name: String(localized: "URL"), value: createStreamWizard.customSrtUrl)
                        TextValueView(
                            name: String(localized: "Stream id"),
                            value: createStreamWizard.customSrtStreamId
                        )
                    } header: {
                        Text("SRT(LA)")
                    }
                } else if createStreamWizard.customProtocol == .rtmp {
                    Section {
                        TextValueView(name: String(localized: "URL"), value: createStreamWizard.customRtmpUrl)
                        TextValueView(
                            name: String(localized: "Stream key"),
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
                            TextValueView(
                                name: String(localized: "URL"),
                                value: createStreamWizard.obsRemoteControlUrl
                            )
                            TextValueView(
                                name: String(localized: "Password"),
                                value: createStreamWizard.obsRemoteControlPassword
                            )
                            TextValueView(
                                name: String(localized: "BRB scene"),
                                value: createStreamWizard.obsRemoteControlBrbScene
                            )
                            TextValueView(
                                name: String(localized: "Source name"),
                                value: createStreamWizard.obsRemoteControlSourceName
                            )
                        } header: {
                            Text("OBS remote control")
                        }
                    }
                }
                Section {
                    TextValueView(
                        name: String(localized: "BTTV emotes"),
                        value: yesOrNo(createStreamWizard.chatBttv)
                    )
                    TextValueView(name: String(localized: "FFZ emotes"), value: yesOrNo(createStreamWizard.chatFfz))
                    TextValueView(
                        name: String(localized: "7TV emotes"),
                        value: yesOrNo(createStreamWizard.chatSeventv)
                    )
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
                HCenter {
                    Button {
                        model.createStreamFromWizard()
                        createStreamWizard.isPresenting = false
                        createStreamWizard.isPresentingSetup = false
                    } label: {
                        Text("Create")
                    }
                    .disabled(createStreamWizard.name.isEmpty)
                }
            }
        }
        .navigationTitle("Summary and stream name")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
