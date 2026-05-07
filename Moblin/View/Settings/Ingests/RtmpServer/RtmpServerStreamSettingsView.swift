import Network
import SwiftUI

struct RtmpServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
    @ObservedObject var rtmpServer: SettingsRtmpServer
    @ObservedObject var stream: SettingsRtmpServerStream

    private func changeStreamKey(value: String) -> String? {
        if model.getRtmpStream(streamKey: value.trim()) == nil {
            return nil
        }
        return String(localized: "Already in use")
    }

    private func submitStreamKey(value: String) {
        let streamKey = value.trim()
        if model.getRtmpStream(streamKey: streamKey) != nil {
            return
        }
        stream.streamKey = streamKey
    }

    private func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        stream.latency = latency
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
                        onChange: changeStreamKey,
                        onSubmit: submitStreamKey
                    )
                    .disabled(model.rtmpServerEnabled())
                } footer: {
                    Text("The stream name is shown in the list of cameras in scene settings.")
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(stream.latency),
                        onChange: isValidIngestLatency,
                        onSubmit: submitLatency,
                        footers: [String(localized: "5 or more milliseconds. 2000 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                    .disabled(model.rtmpServerEnabled())
                } footer: {
                    Text("The higher, the lower risk of stuttering.")
                }
                Section {
                    UrlsView(
                        status: status,
                        formatUrl: { "rtmp://\($0):\(rtmpServer.port)\(rtmpServerApp)/\(stream.streamKey)" }
                    )
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
