import SwiftUI

struct StreamWizardSummarySettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            if model.wizardPlatform == .twitch {
                Section {
                    HStack {
                        Text("Channel name")
                        Spacer()
                        Text(model.wizardTwitchChannelName)
                    }
                    HStack {
                        Text("Channel id")
                        Spacer()
                        Text(model.wizardTwitchChannelId)
                    }
                } header: {
                    Text("Twitch")
                }
            }
            if model.wizardPlatform == .kick {
                Section {
                    HStack {
                        Text("Channel name")
                        Spacer()
                        Text(model.wizardKickChannelName)
                    }
                    HStack {
                        Text("Chatroom id")
                        Spacer()
                        Text(model.wizardKickChatroomId)
                    }
                } header: {
                    Text("Kick")
                }
            }
            if model.wizardNetworkSetup == .obs {
                Section {
                    HStack {
                        Text("IP address or domain name")
                        Spacer()
                        Text(model.wizardObsAddress)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        Text(model.wizardObsPort)
                    }
                } header: {
                    Text("OBS")
                }
            }
            if model.wizardNetworkSetup == .belaboxCloudObs {}
            if model.wizardNetworkSetup == .direct {}
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
