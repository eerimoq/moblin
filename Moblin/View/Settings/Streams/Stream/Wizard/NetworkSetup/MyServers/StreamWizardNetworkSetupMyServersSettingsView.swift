import SwiftUI

struct StreamWizardNetworkSetupMyServersSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupMyServersSrtSettingsView()
                } label: {
                    Text("SRT(LA)")
                }
                NavigationLink {
                    StreamWizardNetworkSetupMyServersRtmpSettingsView()
                } label: {
                    Text("RTMP(S)")
                }
            } header: {
                Text("Protocol")
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .myServers
        }
        .navigationTitle("My server(s)")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
