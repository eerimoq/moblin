import Network
import SwiftUI

struct RtmpServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var stream: SettingsRtmpServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
        model.store()
        model.objectWillChange.send()
    }

    private func submitStreamKey(value: String) {
        stream.streamKey = value.trim()
        model.store()
        model.reloadRtmpServer()
        model.objectWillChange.send()
    }

    private func streamUrl(address: String) -> String {
        return rtmpStreamUrl(address: address, port: port, streamKey: stream.streamKey)
    }

    private func urlImage(interfaceType: NWInterface.InterfaceType) -> String {
        switch interfaceType {
        case .other:
            return "questionmark"
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .wiredEthernet:
            return "cable.connector"
        case .loopback:
            return "questionmark"
        @unknown default:
            return "questionmark"
        }
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Name"),
                    value: stream.name,
                    onSubmit: submitName
                )) {
                    TextItemView(name: String(localized: "Name"), value: stream.name)
                }
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Stream key"),
                    value: stream.streamKey,
                    onSubmit: submitStreamKey
                )) {
                    TextItemView(name: String(localized: "Stream key"), value: stream.streamKey)
                }
            } footer: {
                Text("The stream name is shown in the list of cameras in scene settings.")
            }
            Section {
                List {
                    ForEach(model.ipStatuses, id: \.name) { status in
                        HStack {
                            if stream.streamKey.isEmpty {
                                Text("Stream key missing")
                            } else {
                                Image(systemName: urlImage(interfaceType: status.interfaceType))
                                Text(streamUrl(address: status.ip))
                            }
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = streamUrl(address: status.ip)
                                model.makeToast(title: "URL copied to clipboard")
                            }, label: {
                                Image(systemName: "doc.on.doc")
                            })
                            .disabled(stream.streamKey.isEmpty)
                        }
                    }
                }
            } header: {
                Text("Publish URLs")
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Enter one of the URLs into the RTMP publisher device to send video \
                    to this stream. Usually enter the WiFi URL.
                    """)
                }
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
