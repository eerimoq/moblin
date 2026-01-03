import SwiftUI

struct StreamWizardNetworkSetupMyServersSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardNetworkSetupMyServersSrtSettingsView(
                        model: model,
                        createStreamWizard: createStreamWizard
                    )
                } label: {
                    Text("SRT(LA)")
                }
                NavigationLink {
                    StreamWizardNetworkSetupMyServersRtmpSettingsView(
                        model: model,
                        createStreamWizard: createStreamWizard
                    )
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
