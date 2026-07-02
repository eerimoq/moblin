import Network
import SwiftUI

struct IngestStreamItemView: View {
    let name: String
    let connected: Bool

    var body: some View {
        HStack {
            if connected {
                Image(systemName: "cable.connector")
            } else {
                Image(systemName: "cable.connector.slash")
            }
            Text(name)
            Spacer()
        }
    }
}

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
        stream.audioOffset = max(stream.audioOffset, -stream.latency)
    }

    private var audioOffsetMinMs: Double {
        max(-2000, -Double(stream.latency))
    }

    private var audioOffsetBinding: Binding<Double> {
        Binding(
            get: { Double(stream.audioOffset) },
            set: { stream.audioOffset = Int32($0.rounded()) }
        )
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
                    VStack(alignment: .leading) {
                        Text("Audio offset")
                        HStack {
                            Slider(value: audioOffsetBinding, in: audioOffsetMinMs ... 2000, step: 10)
                                .onChange(of: stream.audioOffset) { _ in
                                    model.setRtmpStreamAudioOffset(stream: stream)
                                }
                            Text("\(stream.audioOffset) ms")
                                .frame(width: 65)
                        }
                    }
                } footer: {
                    Text("Adjust to fix audio/video sync. Positive delays audio, negative advances it.")
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
            IngestStreamItemView(name: stream.name,
                                 connected: model.isRtmpStreamConnected(streamKey: stream.streamKey))
        }
    }
}
