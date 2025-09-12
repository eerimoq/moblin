import SwiftUI

struct LocalOverlaysNetworkInterfaceNamesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func onSubmit(interface: SettingsNetworkInterfaceName, value: String) {
        interface.name = value
    }

    var body: some View {
        Form {
            Section {
                if database.networkInterfaceNames.isEmpty {
                    Text("No known Ethernet network interfaces.")
                } else {
                    List {
                        ForEach(database.networkInterfaceNames) { interface in
                            TextEditNavigationView(
                                title: interface.interfaceName,
                                value: interface.name,
                                onSubmit: { onSubmit(interface: interface, value: $0) },
                                capitalize: true
                            )
                        }
                        .onDelete { indexes in
                            database.networkInterfaceNames.remove(atOffsets: indexes)
                            model.networkInterfaceNamesUpdated()
                        }
                    }
                }
            }
        }
        .navigationTitle("Network interface names")
    }
}
