import SwiftUI

struct LocalOverlaysNetworkInterfaceNamesInterfaceSettingsView: View {
    @EnvironmentObject var model: Model
    var interface: SettingsNetworkInterfaceName

    private func onSubmitInterfaceName(value: String) {
        interface.interfaceName = value.trim()
        model.networkInterfaceNamesUpdated()
        model.store()
    }

    private func onSubmitName(value: String) {
        interface.name = value.trim()
        model.networkInterfaceNamesUpdated()
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: TextEditView(
                title: "Interface name",
                value: interface.interfaceName,
                onSubmit: onSubmitInterfaceName
            )) {
                TextItemView(name: "Interface name", value: interface.interfaceName)
            }
            NavigationLink(destination: TextEditView(
                title: "Name",
                value: interface.name,
                onSubmit: onSubmitName
            )) {
                TextItemView(name: "Name", value: interface.name)
            }
        }
        .navigationTitle("Interface")
        .toolbar {
            SettingsToolbar()
        }
    }
}
