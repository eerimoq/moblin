import SwiftUI

struct StreamSrtSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        guard latency >= 0 else {
            return
        }
        stream.srt.latency = latency
        model.storeAndReloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Latency"),
                    value: String(stream.srt.latency),
                    onSubmit: submitLatency,
                    footer: Text(
                        """
                        Zero or more milliseconds. Any latency parameter given in the URL \
                        overrides this value.
                        """
                    )
                )) {
                    TextItemView(name: String(localized: "Latency"), value: String(stream.srt.latency))
                }
                .disabled(stream.enabled && model.isLive)
                Toggle("Big packets", isOn: Binding(get: {
                    stream.srt.mpegtsPacketsPerPacket == 7
                }, set: { value in
                    if value {
                        stream.srt.mpegtsPacketsPerPacket = 7
                    } else {
                        stream.srt.mpegtsPacketsPerPacket = 6
                    }
                    model.storeAndReloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
                Toggle("Adaptive bitrate", isOn: Binding(get: {
                    stream.adaptiveBitrate
                }, set: { value in
                    stream.adaptiveBitrate = value
                    model.storeAndReloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
            } footer: {
                VStack(alignment: .leading) {
                    Text("Adaptive bitrate is experimental.")
                    Text("")
                    Text(
                        """
                        Big packets means 7 MPEG-TS packets per SRT packet, 6 otherwise. \
                        Sometimes Android hotspots does not work with big packets.
                        """
                    )
                }
            }
        }
        .navigationTitle("SRT(LA)")
        .toolbar {
            SettingsToolbar()
        }
    }
}
