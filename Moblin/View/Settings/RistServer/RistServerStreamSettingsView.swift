import Network
import SwiftUI

private struct UrlsView: View {
    let model: Model
    @ObservedObject var status: StatusOther
    let port: UInt16
    let virtualDestinationPort: UInt16

    private func formatUrl(ip: String) -> String {
        return "rist://\(ip):\(port)?virt-dst-port=\(virtualDestinationPort)"
    }

    var body: some View {
        NavigationLink {
            Form {
                UrlsIpv4View(model: model, status: status, formatUrl: formatUrl)
            }
            .navigationTitle("URLs")
        } label: {
            Text("URLs")
        }
    }
}

struct RistServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
    @ObservedObject var ristServer: SettingsRistServer
    @ObservedObject var stream: SettingsRistServerStream

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        stream.virtualDestinationPort = port
        model.reloadRistServer()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: ristServer.streams)
                        .disabled(model.ristServerEnabled())
                } footer: {
                    Text("The stream name is shown in the list of cameras in scene settings.")
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Virtual port"),
                        value: String(stream.virtualDestinationPort),
                        onChange: isValidPort,
                        onSubmit: submitPort,
                        keyboardType: .numbersAndPunctuation
                    )
                    .disabled(ristServer.enabled)
                } footer: {
                    Text("The virtual destination port for this stream.")
                }
                Section {
                    UrlsView(model: model,
                             status: status,
                             port: ristServer.port,
                             virtualDestinationPort: stream.virtualDestinationPort)
                } header: {
                    Text("Publish URLs")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("""
                        Enter one of the URLs into the RIST publisher device to send video \
                        to this stream. Usually enter the WiFi or Personal Hotspot URL.
                        """)
                    }
                }
            }
            .navigationTitle("Stream")
        } label: {
            HStack {
                if model.isRistStreamConnected(port: stream.virtualDestinationPort) {
                    Image(systemName: "cable.connector")
                } else {
                    Image(systemName: "cable.connector.slash")
                }
                Text(stream.name)
                Spacer()
            }
        }
    }
}
