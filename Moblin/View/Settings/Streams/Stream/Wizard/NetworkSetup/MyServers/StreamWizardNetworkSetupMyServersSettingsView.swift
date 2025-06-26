import SwiftUI

struct StreamWizardNetworkSetupMyServersSettingsView: View {
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupMyServersSrtSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("SRT(LA)")
                }
                NavigationLink {
                    StreamWizardNetworkSetupMyServersRtmpSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("RTMP(S)")
                }
            } header: {
                Text("Protocol")
            }
        }
        .onAppear {
            createStreamWizard.networkSetup = .myServers
        }
        .navigationTitle("My server(s)")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
