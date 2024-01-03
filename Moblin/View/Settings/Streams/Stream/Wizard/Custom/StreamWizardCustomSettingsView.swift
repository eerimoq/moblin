import SwiftUI

struct StreamWizardCustomSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamWizardCustomSrtSettingsView()) {
                    Text("SRT(LA)")
                }
                NavigationLink(destination: StreamWizardCustonRtmpSettingsView()) {
                    Text("RTMP(S)")
                }
            } header: {
                Text("Protocol")
            }
            Section {
                NavigationLink(destination: StreamWizardSummarySettingsView()) {
                    WizardSkipButtonView()
                }
            }
        }
        .onAppear {
            model.wizardPlatform = .custom
            model.wizardNetworkSetup = .none
            model.wizardCustomProtocol = .none
            model.wizardName = "Custom"
        }
        .navigationTitle("Custom")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
