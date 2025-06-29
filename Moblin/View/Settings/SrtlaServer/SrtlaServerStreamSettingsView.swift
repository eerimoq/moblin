import Network
import SwiftUI

private func makeStreamUrl(proto: String, address: String, port: UInt16, streamId: String) -> String {
    var url = "\(proto)://\(address):\(port)"
    if !streamId.isEmpty {
        url += "?streamid=\(streamId)"
    }
    return url
}

private struct ProtocolUrlsView: View {
    @ObservedObject var status: StatusOther
    let proto: String
    let port: UInt16
    let streamId: String

    private func title() -> String {
        return "\(proto.uppercased()) URLs"
    }

    var body: some View {
        NavigationLink {
            Form {
                List {
                    ForEach(status.ipStatuses.filter { $0.ipType == .ipv4 }) { status in
                        InterfaceView(
                            proto: proto,
                            ip: status.ipType.formatAddress(status.ip),
                            port: port,
                            streamId: streamId,
                            image: urlImage(interfaceType: status.interfaceType)
                        )
                    }
                    InterfaceView(
                        proto: proto,
                        ip: personalHotspotLocalAddress,
                        port: port,
                        streamId: streamId,
                        image: "personalhotspot"
                    )
                    ForEach(status.ipStatuses.filter { $0.ipType == .ipv6 }) { status in
                        InterfaceView(
                            proto: proto,
                            ip: status.ipType.formatAddress(status.ip),
                            port: port,
                            streamId: streamId,
                            image: urlImage(interfaceType: status.interfaceType)
                        )
                    }
                }
            }
            .navigationTitle(title())
        } label: {
            Text(title())
        }
    }
}

private struct InterfaceView: View {
    @EnvironmentObject var model: Model
    let proto: String
    let ip: String
    let port: UInt16
    let streamId: String
    let image: String

    private func streamUrl() -> String {
        return makeStreamUrl(proto: proto, address: ip, port: port, streamId: streamId)
    }

    var body: some View {
        HStack {
            Image(systemName: image)
            Text(streamUrl())
            Spacer()
            Button {
                UIPasteboard.general.string = streamUrl()
                model.makeToast(title: "URL copied to clipboard")
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .disabled(streamId.isEmpty)
        }
    }
}

struct SrtlaServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
    var srtPort: UInt16
    var srtlaPort: UInt16
    var stream: SettingsSrtlaServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
        model.objectWillChange.send()
    }

    private func submitStreamId(value: String) {
        let streamId = value.trim()
        guard streamId.wholeMatch(of: /[a-zA-Z0-9]*/) != nil else {
            return
        }
        if model.getSrtlaStream(streamId: streamId) != nil {
            return
        }
        stream.streamId = streamId
        model.reloadSrtlaServer()
        model.objectWillChange.send()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Name"),
                    value: stream.name,
                    onSubmit: submitName,
                    capitalize: true
                )
                .disabled(model.srtlaServerEnabled())
                TextEditNavigationView(
                    title: String(localized: "Stream id"),
                    value: stream.streamId,
                    onSubmit: submitStreamId,
                    footers: [String(localized: "May only contain lower case letters.")]
                )
                .disabled(model.srtlaServerEnabled())
            } footer: {
                Text("The stream name is shown in the list of cameras in scene settings.")
            }
            Section {
                Toggle("Auto select mic", isOn: Binding(get: {
                    stream.autoSelectMic!
                }, set: { value in
                    stream.autoSelectMic = value
                    model.reloadSrtlaServer()
                    model.objectWillChange.send()
                }))
                .disabled(model.srtlaServerEnabled())
            } footer: {
                Text("Automatically select the stream's audio as mic when connected.")
            }
            Section {
                if model.srtlaServerEnabled() {
                    ProtocolUrlsView(status: status, proto: "srt", port: srtPort, streamId: stream.streamId)
                    ProtocolUrlsView(status: status, proto: "srtla", port: srtlaPort, streamId: stream.streamId)
                } else {
                    Text("Enable the SRT(LA) server to see URLs.")
                }
            } header: {
                Text("Publish URLs")
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Enter one of the URLs into the SRT(LA) publisher device to send video \
                    to this stream. Usually enter the WiFi or Personal Hotspot URL.
                    """)
                }
            }
        }
        .navigationTitle("Stream")
    }
}
