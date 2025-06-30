import Network
import SwiftUI

private struct UrlsView: View {
    let model: Model
    @ObservedObject var status: StatusOther
    let port: UInt16
    let streamKey: String

    private func formatUrl(ip: String) -> String {
        return "rtmp://\(ip):\(port)\(rtmpServerApp)/\(streamKey)"
    }

    var body: some View {
        NavigationLink {
            Form {
                UrlsIpv4View(model: model, status: status, formatUrl: formatUrl)
                UrlsIpv6View(model: model, status: status, formatUrl: formatUrl)
            }
            .navigationTitle("URLs")
        } label: {
            Text("URLs")
        }
    }
}

struct RtmpServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
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
                    UrlsView(model: model, status: status, port: port, streamKey: stream.streamKey)
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
