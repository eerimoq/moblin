import SwiftUI

struct LocalOverlaysNetworkInterfaceNamesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(model.database.networkInterfaceNames!) { interface in
                        NavigationLink(
                            destination: LocalOverlaysNetworkInterfaceNamesInterfaceSettingsView(
                                interface: interface
                            )
                        ) {
                            TextItemView(name: interface.interfaceName, value: interface.name)
                        }
                    }
                    .onDelete { indexes in
                        model.database.networkInterfaceNames?.remove(atOffsets: indexes)
                        model.networkInterfaceNamesUpdated()
                        model.store()
                    }
                    CreateButtonView {
                        let interface = SettingsNetworkInterfaceName()
                        interface.interfaceName = "enX"
                        model.database.networkInterfaceNames?.append(interface)
                        model.store()
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
