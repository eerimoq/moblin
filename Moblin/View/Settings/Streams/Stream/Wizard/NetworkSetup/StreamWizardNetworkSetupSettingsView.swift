import SwiftUI

struct StreamWizardNetworkSetupSettingsView: View {
    let platform: String

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Section {
                    NavigationLink {
                        StreamWizardNetworkSetupObsSettingsView()
                    } label: {
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
                    NavigationLink {
                        StreamWizardNetworkSetupBelaboxSettingsView()
                    } label: {
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
                    Text("Best possible stability. Uses bonding. Paid third-party service.")
                }
                Section {
                    NavigationLink {
                        StreamWizardNetworkSetupDirectSettingsView()
                    } label: {
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
                Section {
                    NavigationLink {
                        StreamWizardNetworkSetupMyServersSettingsView()
                    } label: {
                        HStack {
                            Text("Moblin")
                            Image(systemName: "arrow.right")
                            Text("My server(s)")
                            Image(systemName: "arrow.right")
                            Text(platform)
                        }
                    }
                } footer: {
                    Text("Best possible stability. May use bonding. Most flexible setup.")
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
