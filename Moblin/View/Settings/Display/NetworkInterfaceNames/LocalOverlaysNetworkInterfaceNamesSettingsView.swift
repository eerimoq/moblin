import SwiftUI

struct LocalOverlaysNetworkInterfaceNamesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func deleteNetworkInterface(at offsets: IndexSet) {
        database.networkInterfaceNames.remove(atOffsets: offsets)
        model.networkInterfaceNamesUpdated()
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
                                onSubmit: {
                                    interface.name = $0
                                },
                                capitalize: true
                            )
                            .contextMenuDeleteButton {
                                if let index = database.networkInterfaceNames
                                    .firstIndex(where: { $0.id == interface.id })
                                {
                                    deleteNetworkInterface(at: IndexSet(integer: index))
                                }
                            }
                        }
                        .onDelete(perform: deleteNetworkInterface)
                    }
                }
            }
        }
        .navigationTitle("Network interface names")
    }
}
