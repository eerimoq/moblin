import SwiftUI

struct HttpProxySettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
    @ObservedObject var httpProxy: SettingsHttpProxy

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            model.makePortErrorToast(port: value)
            return
        }
        httpProxy.port = port
        model.reloadHttpProxyServer()
    }

    var body: some View {
        Form {
            Section {
                Text("""
                The HTTP proxy executes HTTP requests over the network interface that is most likely \
                to have internet connectivity.
                """)
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Port"),
                    value: String(httpProxy.port),
                    onChange: isValidPort,
                    onSubmit: submitPort,
                    keyboardType: .numbersAndPunctuation,
                    placeholder: String(DefaultTcpPorts.httpProxy)
                )
            }
            Section {
                Toggle("Enabled", isOn: $httpProxy.enabled)
                    .onChange(of: httpProxy.enabled) { _ in
                        model.httpProxyServerChanged()
                    }
            } header: {
                Text("This device")
            } footer: {
                Text("Moblin's web browser and browser widgets use the proxy.")
            }
            Section {
                Toggle("Enabled", isOn: $httpProxy.localNetwork)
                    .onChange(of: httpProxy.localNetwork) { _ in
                        model.httpProxyServerChanged()
                    }
            } header: {
                Text("Local network")
            } footer: {
                Text("""
                Allow other devices on the local network to execute HTTP requests through this proxy. \
                Anyone on the local network can use it, so only enable it on networks you trust.
                """)
            }
            if httpProxy.localNetwork {
                Section {
                    UrlsView(status: status, formatUrl: { "http://\($0):\(httpProxy.port)" })
                } footer: {
                    Text("Configure one of the URL:s as HTTP proxy in the other device.")
                }
            }
        }
        .navigationTitle("HTTP proxy")
    }
}
