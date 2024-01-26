import SwiftUI

struct LocalOverlaysNetworkInterfaceNamesSettingsView: View {
    @EnvironmentObject var model: Model

    private func onSubmit(interface: SettingsNetworkInterfaceName, value: String) {
        interface.name = value
        model.store()
    }

    var body: some View {
        Form {
            Section {
                if model.database.networkInterfaceNames!.isEmpty {
                    Text("No known Ethernet network interfaces.")
                } else {
                    List {
                        ForEach(model.database.networkInterfaceNames!) { interface in
                            TextEditNavigationView(
                                title: interface.interfaceName,
                                value: interface.name,
                                onSubmit: { value in onSubmit(interface: interface, value: value) },
                                capitalize: true
                            )
                        }
                        .onDelete { indexes in
                            model.database.networkInterfaceNames!.remove(atOffsets: indexes)
                            model.networkInterfaceNamesUpdated()
                            model.store()
                        }
                    }
                }
            }
        }
        .navigationTitle("Network interface names")
        .toolbar {
            SettingsToolbar()
        }
    }
}
