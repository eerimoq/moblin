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
                    Text("Best possible stability. Uses bonding. Paid third-party service.")
                }
                if false {
                    Section {
                        NavigationLink(destination: StreamWizardNetworkSetupIrlToolkitSettingsView()) {
                            HStack {
                                Text("Moblin")
                                Image(systemName: "arrow.right")
                                Text("Free IRLToolkit bonding")
                                Image(systemName: "arrow.right")
                                Text(platform)
                            }
                        }
                    } footer: {
                        Text("""
                        Best possible stability. Uses bonding. Free third-party service \
                        provided as a courtesy by IRLToolkit. Not to be used if you pay \
                        for IRLToolkit.
                        """)
                    }
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
                Section {
                    NavigationLink(destination: StreamWizardNetworkSetupMyServersSettingsView()) {
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
