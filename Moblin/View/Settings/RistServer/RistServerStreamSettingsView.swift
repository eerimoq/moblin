import Network
import SwiftUI

private struct UrlsView: View {
    let model: Model
    @ObservedObject var status: StatusOther
    let port: UInt16

    private func formatUrl(ip: String) -> String {
        return "rist://\(ip):\(port)"
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
        guard let port = UInt16(value.trim()), port > 0 else {
            stream.portString = String(stream.port)
            model.makePortErrorToast(port: value)
            return
        }
        stream.port = port
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
                    TextEditBindingNavigationView(
                        title: String(localized: "Port"),
                        value: $stream.portString,
                        onSubmit: submitPort,
                        keyboardType: .numbersAndPunctuation
                    )
                    .disabled(ristServer.enabled)
                } footer: {
                    Text("The UDP port this RIST stream listens for a RIST publisher on.")
                }
                Section {
                    if model.ristServerEnabled() {
                        UrlsView(model: model, status: status, port: stream.port)
                    } else {
                        Text("Enable the RIST server to see URLs.")
                    }
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
                if model.isRistStreamConnected(port: stream.port) {
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
