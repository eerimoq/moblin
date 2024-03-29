import SwiftUI

struct StreamWizardSummarySettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            if model.wizardPlatform == .twitch {
                Section {
                    TextValueView(
                        name: String(localized: "Channel name"),
                        value: model.wizardTwitchChannelName
                    )
                    TextValueView(name: String(localized: "Channel id"), value: model.wizardTwitchChannelId)
                } header: {
                    Text("Twitch")
                }
            } else if model.wizardPlatform == .kick {
                Section {
                    TextValueView(name: String(localized: "Channel name"), value: model.wizardKickChannelName)
                } header: {
                    Text("Kick")
                }
            } else if model.wizardPlatform == .youTube {
                Section {
                    TextValueView(name: String(localized: "API key"), value: model.wizardYouTubeApiKey)
                    TextValueView(name: String(localized: "Video id"), value: model.wizardYouTubeVideoId)
                } header: {
                    Text("YouTube")
                }
            } else if model.wizardPlatform == .afreecaTv {
                Section {
                    TextValueView(
                        name: String(localized: "Channel name"),
                        value: model.wizardAfreecaTvChannelName
                    )
                    TextValueView(name: String(localized: "Video id"), value: model.wizardAfreecsTvCStreamId)
                } header: {
                    Text("AfreecaTV")
                }
            }
            if model.wizardNetworkSetup == .obs {
                Section {
                    TextValueView(
                        name: String(localized: "IP address or domain name"),
                        value: model.wizardObsAddress
                    )
                    TextValueView(name: String(localized: "Port"), value: model.wizardObsPort)
                } header: {
                    Text("OBS")
                }
            } else if model.wizardNetworkSetup == .belaboxCloudObs {
                Section {
                    TextValueView(name: String(localized: "Ingest URL"), value: model.wizardBelaboxUrl)
                } header: {
                    Text("BELABOX cloud")
                }
            } else if model.wizardNetworkSetup == .direct {
                Section {
                    if model.wizardPlatform == .twitch {
                        TextValueView(
                            name: String(localized: "Nearby ingest endpoint"),
                            value: model.wizardDirectIngest
                        )
                        TextValueView(
                            name: String(localized: "Stream key"),
                            value: model.wizardDirectStreamKey
                        )
                    } else if model.wizardPlatform == .kick {
                        TextValueView(name: String(localized: "Stream URL"), value: model.wizardDirectIngest)
                        TextValueView(
                            name: String(localized: "Stream key"),
                            value: model.wizardDirectStreamKey
                        )
                    } else if model.wizardPlatform == .youTube {
                        TextValueView(name: String(localized: "Stream URL"), value: model.wizardDirectIngest)
                        TextValueView(
                            name: String(localized: "Stream key"),
                            value: model.wizardDirectStreamKey
                        )
                    } else if model.wizardPlatform == .afreecaTv {
                        TextValueView(name: String(localized: "Stream URL"), value: model.wizardDirectIngest)
                        TextValueView(
                            name: String(localized: "Stream key"),
                            value: model.wizardDirectStreamKey
                        )
                    }
                } header: {
                    Text("Direct")
                }
            }
            if model.wizardPlatform == .custom {
                if model.wizardCustomProtocol == .srt {
                    Section {
                        TextValueView(name: String(localized: "URL"), value: model.wizardCustomSrtUrl)
                        TextValueView(
                            name: String(localized: "Stream id"),
                            value: model.wizardCustomSrtStreamId
                        )
                    } header: {
                        Text("SRT(LA)")
                    }
                } else if model.wizardCustomProtocol == .rtmp {
                    Section {
                        TextValueView(name: String(localized: "URL"), value: model.wizardCustomRtmpUrl)
                        TextValueView(
                            name: String(localized: "Stream key"),
                            value: model.wizardCustomRtmpStreamKey
                        )
                    } header: {
                        Text("RTMP(S)")
                    }
                }
            } else {
                if model.wizardNetworkSetup != .direct {
                    if model.wizardObsRemoteControlEnabled {
                        Section {
                            TextValueView(
                                name: String(localized: "URL"),
                                value: model.wizardObsRemoteControlUrl
                            )
                            TextValueView(
                                name: String(localized: "Password"),
                                value: model.wizardObsRemoteControlPassword
                            )
                            TextValueView(
                                name: String(localized: "Source name"),
                                value: model.wizardObsRemoteControlSourceName
                            )
                        } header: {
                            Text("OBS remote control")
                        }
                    }
                }
                Section {
                    TextValueView(
                        name: String(localized: "BTTV emotes"),
                        value: yesOrNo(model.wizardChatBttv)
                    )
                    TextValueView(name: String(localized: "FFZ emotes"), value: yesOrNo(model.wizardChatFfz))
                    TextValueView(
                        name: String(localized: "7TV emotes"),
                        value: yesOrNo(model.wizardChatSeventv)
                    )
                } header: {
                    Text("Chat")
                }
            }
            Section {
                TextField("Name", text: $model.wizardName)
            } header: {
                Text("Stream name")
                    .disableAutocorrection(true)
            }
            Section {
                HStack {
                    Spacer()
                    Button {
                        model.createStreamFromWizard()
                        model.isPresentingWizard = false
                        model.isPresentingSetupWizard = false
                    } label: {
                        Text("Create")
                    }
                    .disabled(model.wizardName.isEmpty)
                    Spacer()
                }
            }
        }
        .navigationTitle("Summary and stream name")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
