import SwiftUI

struct StreamWizardCustomSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardCustomSrtSettingsView()
                } label: {
                    Text("SRT(LA)")
                }
                NavigationLink {
                    StreamWizardCustomRtmpSettingsView()
                } label: {
                    Text("RTMP(S)")
                }
                NavigationLink {
                    StreamWizardCustomRistSettingsView()
                } label: {
                    Text("RIST")
                }
            } header: {
                Text("Protocol")
            }
            Section {
                NavigationLink {
                    StreamWizardSummarySettingsView()
                } label: {
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
