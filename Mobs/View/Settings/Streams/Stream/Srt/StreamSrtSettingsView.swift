import SwiftUI

struct StreamSrtSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    var stream: SettingsStream

    func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        guard latency >= 0 else {
            return
        }
        stream.srt!.latency = latency
        model.reloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: TextEditView(
                    toolbar: toolbar,
                    title: "Latency",
                    value: String(stream.srt!.latency),
                    onSubmit: submitLatency,
                    footer: Text(
                        """
                        Zero or more milliseconds. Any latency parameter given in the URL \
                        overrides this value.
                        """
                    )
                )) {
                    TextItemView(name: "Latency", value: String(stream.srt!.latency))
                }
                Toggle("Big packets", isOn: Binding(get: {
                    stream.srt!.mpegtsPacketsPerPacket == 7
                }, set: { value in
                    if value {
                        stream.srt!.mpegtsPacketsPerPacket = 7
                    } else {
                        stream.srt!.mpegtsPacketsPerPacket = 6
                    }
                    model.store()
                    model.reloadStreamIfEnabled(stream: stream)
                }))
                Toggle("Adaptive bitrate*", isOn: Binding(get: {
                    stream.adaptiveBitrate!
                }, set: { value in
                    stream.adaptiveBitrate = value
                    model.store()
                    if stream.enabled {
                        model.setAdaptiveBitrate(stream: stream)
                    }
                }))
            } footer: {
                Text(
                    "* Adaptive bitrate is experimental and does not work very well."
                )
                Text("")
                Text(
                    "Big packets means 7 MPEG-TS packets per SRT packet, 6 otherwise."
                )
            }
        }
        .navigationTitle("SRT(LA)")
        .toolbar {
            toolbar
        }
    }
}
