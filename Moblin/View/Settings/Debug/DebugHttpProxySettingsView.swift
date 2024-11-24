import SwiftUI

struct DebugHttpProxySettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.debug.httpProxy!.enabled
                }, set: { value in
                    model.database.debug.httpProxy!.enabled = value
                    model.createUrlSession()
                    model.reloadConnections()
                }))
                TextEditNavigationView(
                    title: String(localized: "Host"),
                    value: model.database.debug.httpProxy!.host
                ) {
                    model.database.debug.httpProxy!.host = $0.trim()
                    model.createUrlSession()
                    model.reloadConnections()
                }
                TextEditNavigationView(
                    title: String(localized: "Port"),
                    value: String(model.database.debug.httpProxy!.port)
                ) {
                    guard let port = UInt16($0) else {
                        return
                    }
                    model.database.debug.httpProxy!.port = port
                    model.createUrlSession()
                    model.reloadConnections()
                }
            } footer: {
                Text("Currently only used for Twitch websockets. Authentication may be added later.")
            }
        }
        .navigationTitle("HTTP proxy")
    }
}
