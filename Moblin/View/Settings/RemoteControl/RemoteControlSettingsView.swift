import SwiftUI

struct RemoteControlSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitClientAddress(value: String) {
        model.database.remoteControl!.client.address = value.trim()
        model.store()
        model.reloadRemoteControlClient()
    }

    private func submitClientPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.remoteControl!.client.port = port
        model.store()
        model.reloadRemoteControlClient()
    }

    private func submitClientPassword(value: String) {
        model.database.remoteControl!.client.password = value.trim()
        model.store()
        model.reloadRemoteControlClient()
    }

    private func submitServerUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        model.database.remoteControl!.server.url = value
        model.store()
        model.reloadRemoteControlClient()
    }

    private func submitServerPassword(value: String) {
        model.database.remoteControl!.server.password = value.trim()
        model.store()
        model.reloadRemoteControlClient()
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.remoteControl!.client.enabled
                }, set: { value in
                    model.database.remoteControl!.client.enabled = value
                    model.store()
                })) {
                    Text("Enabled")
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Address"),
                    value: model.database.remoteControl!.client.address,
                    onSubmit: submitClientAddress
                )) {
                    TextItemView(
                        name: String(localized: "Address"),
                        value: model.database.remoteControl!.client.address
                    )
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Port"),
                    value: String(model.database.remoteControl!.client.port),
                    onSubmit: submitClientPort
                )) {
                    TextItemView(
                        name: String(localized: "Port"),
                        value: String(model.database.remoteControl!.client.port)
                    )
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Password"),
                    value: model.database.remoteControl!.client.password,
                    onSubmit: submitClientPassword
                )) {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.remoteControl!.client.password,
                        sensitive: true
                    )
                }
            } header: {
                Text("Client")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.remoteControl!.server.enabled
                }, set: { value in
                    model.database.remoteControl!.server.enabled = value
                    model.store()
                })) {
                    Text("Enabled")
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "URL"),
                    value: model.database.remoteControl!.server.url,
                    onSubmit: submitServerUrl,
                    keyboardType: .URL
                )) {
                    TextItemView(
                        name: String(localized: "URL"),
                        value: model.database.remoteControl!.server.url
                    )
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Password"),
                    value: model.database.remoteControl!.server.password,
                    onSubmit: submitServerPassword
                )) {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.remoteControl!.server.password,
                        sensitive: true
                    )
                }
            } header: {
                Text("Server")
            }
        }
        .navigationTitle("Remote control")
        .toolbar {
            SettingsToolbar()
        }
    }
}
