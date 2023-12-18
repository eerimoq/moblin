import SwiftUI

struct StreamWizardNetworkSetupSettingsView: View {
    let platform: String

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Section {
                    NavigationLink(destination: StreamWizardNetworkSetupObsSettingsView()) {
                        HStack {
                            Text("Moblin")
                            Image(systemName: "arrow.right")
                            Text("OBS")
                            Image(systemName: "arrow.right")
                            Text(platform)
                        }
                    }
                } footer: {
                    Text("Good stability in most network conditions.")
                }
                Section {
                    NavigationLink(destination: StreamWizardNetworkSetupBelaboxSettingsView()) {
                        HStack {
                            Text("Moblin")
                            Image(systemName: "arrow.right")
                            Text("BELABOX cloud")
                            Image(systemName: "arrow.right")
                            Text("OBS")
                            Image(systemName: "arrow.right")
                            Text(platform)
                        }
                    }
                } footer: {
                    Text("Best possible stability.")
                }
                Section {
                    NavigationLink(destination: StreamWizardNetworkSetupDirectSettingsView()) {
                        HStack {
                            Text("Moblin")
                            Image(systemName: "arrow.right")
                            Text(platform)
                        }
                    }
                } footer: {
                    Text(
                        """
                        Often bad stability if network connection is unstable. No server side \
                        disconnection protection possible.
                        """
                    )
                }
            }
            Spacer()
        }
        .navigationTitle("Network setup")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
