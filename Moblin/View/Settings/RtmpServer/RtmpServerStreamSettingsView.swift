import Network
import SwiftUI

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

private struct InterfaceView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var streamKey: String
    var image: String
    var ip: String

    private func streamUrl() -> String {
        return rtmpStreamUrl(address: ip, port: port, streamKey: streamKey)
    }

    var body: some View {
        HStack {
            if streamKey.isEmpty {
                Text("Stream key missing")
            } else {
                Image(systemName: image)
                Text(streamUrl())
            }
            Spacer()
            Button(action: {
                UIPasteboard.general.string = streamUrl()
                model.makeToast(title: "URL copied to clipboard")
            }, label: {
                Image(systemName: "doc.on.doc")
            })
            .disabled(streamKey.isEmpty)
        }
    }
}

struct RtmpServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var stream: SettingsRtmpServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
        model.objectWillChange.send()
    }

    private func submitStreamKey(value: String) {
        let streamKey = value.trim()
        if model.getRtmpStream(streamKey: streamKey) != nil {
            return
        }
        stream.streamKey = streamKey
        model.reloadRtmpServer()
        model.objectWillChange.send()
    }

    func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        stream.latency = max(latency, 250)
        model.reloadRtmpServer()
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
                .disabled(model.rtmpServerEnabled())
                TextEditNavigationView(
                    title: String(localized: "Stream key"),
                    value: stream.streamKey,
                    onSubmit: submitStreamKey
                )
                .disabled(model.rtmpServerEnabled())
            } footer: {
                Text("The stream name is shown in the list of cameras in scene settings.")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Latency"),
                    value: String(stream.latency!),
                    onSubmit: submitLatency,
                    footers: [String(localized: "250 or more milliseconds. 2000 ms by default.")],
                    keyboardType: .numbersAndPunctuation,
                    valueFormat: { "\($0) ms" }
                )
                .disabled(model.rtmpServerEnabled())
            } footer: {
                Text("The higher, the lower risk of stuttering.")
            }
            Section {
                Toggle("Auto select mic", isOn: Binding(get: {
                    stream.autoSelectMic!
                }, set: { value in
                    stream.autoSelectMic = value
                    model.reloadRtmpServer()
                    model.objectWillChange.send()
                }))
                .disabled(model.rtmpServerEnabled())
            } footer: {
                Text("Automatically select the stream's audio as mic when connected.")
            }
            Section {
                if model.rtmpServerEnabled() {
                    List {
                        ForEach(model.ipStatuses.filter { $0.ipType == .ipv4 }) { status in
                            InterfaceView(
                                port: port,
                                streamKey: stream.streamKey,
                                image: urlImage(interfaceType: status.interfaceType),
                                ip: status.ipType.formatAddress(status.ip)
                            )
                        }
                        InterfaceView(
                            port: port,
                            streamKey: stream.streamKey,
                            image: "personalhotspot",
                            ip: personalHotspotLocalAddress
                        )
                        ForEach(model.ipStatuses.filter { $0.ipType == .ipv6 }) { status in
                            InterfaceView(
                                port: port,
                                streamKey: stream.streamKey,
                                image: urlImage(interfaceType: status.interfaceType),
                                ip: status.ipType.formatAddress(status.ip)
                            )
                        }
                    }
                } else {
                    Text("Enable the RTMP server to see URLs.")
                }
            } header: {
                Text("Publish URLs")
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Enter one of the URLs into the RTMP publisher device to send video \
                    to this stream. Usually enter the WiFi or Personal Hotspot URL.
                    """)
                }
            }
        }
        .navigationTitle("Stream")
    }
}
