import SwiftUI

struct StreamWizardSummarySettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            if model.wizardPlatform == .twitch {
                Section {
                    TextItemView(name: "Channel name", value: model.wizardTwitchChannelName)
                    TextItemView(name: "Channel id", value: model.wizardTwitchChannelId)
                } header: {
                    Text("Twitch")
                }
            } else if model.wizardPlatform == .kick {
                Section {
                    TextItemView(name: "Channel name", value: model.wizardKickChannelName)
                    TextItemView(name: "Chatroom id", value: model.wizardKickChatroomId)
                } header: {
                    Text("Kick")
                }
            }
            if model.wizardNetworkSetup == .obs {
                Section {
                    TextItemView(name: "IP address or domain name", value: model.wizardObsAddress)
                    TextItemView(name: "Port", value: model.wizardObsPort)
                } header: {
                    Text("OBS")
                }
            } else if model.wizardNetworkSetup == .belaboxCloudObs {
                Section {
                    TextItemView(name: "Ingest URL", value: model.wizardBelaboxUrl)
                } header: {
                    Text("BELABOX cloud")
                }
            } else if model.wizardNetworkSetup == .direct {
                Section {
                    if model.wizardPlatform == .twitch {
                        TextItemView(name: "Nearby ingest endpoint", value: model.wizardDirectIngest)
                        TextItemView(name: "Stream key", value: model.wizardDirectStreamKey)
                    } else if model.wizardPlatform == .kick {
                        TextItemView(name: "Stream URL", value: model.wizardDirectIngest)
                        TextItemView(name: "Stream key", value: model.wizardDirectStreamKey)
                    }
                } header: {
                    Text("Direct")
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
