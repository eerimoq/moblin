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
    @ObservedObject var rtmpServer: SettingsRtmpServer
    @ObservedObject var stream: SettingsRtmpServerStream

    private func submitStreamKey(value: String) {
        let streamKey = value.trim()
        if model.getRtmpStream(streamKey: streamKey) != nil {
            return
        }
        stream.streamKey = streamKey
    }

    func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            stream.latencyString = String(stream.latency)
            return
        }
        stream.latency = latency.clamped(to: 250 ... 10000)
        stream.latencyString = String(stream.latency)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: rtmpServer.streams)
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
                    TextEditBindingNavigationView(
                        title: String(localized: "Latency"),
                        value: $stream.latencyString,
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
                    UrlsView(model: model, status: status, port: rtmpServer.port, streamKey: stream.streamKey)
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
        } label: {
            HStack {
                if model.isRtmpStreamConnected(streamKey: stream.streamKey) {
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
