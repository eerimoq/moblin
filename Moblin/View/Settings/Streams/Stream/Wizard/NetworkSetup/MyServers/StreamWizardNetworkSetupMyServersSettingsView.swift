import SwiftUI

struct StreamWizardNetworkSetupMyServersSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamWizardNetworkSetupMyServersSrtSettingsView()) {
                    Text("SRT(LA)")
                }
                NavigationLink(destination: StreamWizardNetworkSetupMyServersRtmpSettingsView()) {
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
