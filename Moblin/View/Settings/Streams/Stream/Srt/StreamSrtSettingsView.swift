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

    func submitOverheadBandwidth(value: String) {
        guard let overheadBandwidth = Int32(value) else {
            return
        }
        guard overheadBandwidth >= 5 && overheadBandwidth <= 100 else {
            return
        }
        stream.srt.overheadBandwidth = overheadBandwidth
        model.store()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Latency"),
                    value: String(stream.srt.latency),
                    onSubmit: submitLatency,
                    footer: Text(
                        """
                        Zero or more milliseconds. Any latency parameter given in the URL \
                        overrides this value.
                        """
                    ),
                    valueFormat: { "\($0) ms" }
                )
                .disabled(stream.enabled && model.isLive)
                NavigationLink(destination: StreamSrtAdaptiveBitrateSettingsView(stream: stream)) {
                    Toggle("Adaptive bitrate", isOn: Binding(get: {
                        stream.adaptiveBitrate
                    }, set: { value in
                        stream.adaptiveBitrate = value
                        model.storeAndReloadStreamIfEnabled(stream: stream)
                    }))
                    .disabled(stream.enabled && model.isLive)
                }
                NavigationLink(destination: StreamSrtConnectionPriorityView(stream: stream)) {
                    Text("Connection priorities")
                }
                Toggle("Max bandwidth follows input", isOn: Binding(get: {
                    stream.srt.maximumBandwidthFollowInput!
                }, set: { value in
                    stream.srt.maximumBandwidthFollowInput = value
                    model.storeAndReloadStreamIfEnabled(stream: stream)
                }))
                .disabled(stream.enabled && model.isLive)
                TextEditNavigationView(
                    title: String(localized: "Overhead bandwidth"),
                    value: String(stream.srt.overheadBandwidth!),
                    onSubmit: submitOverheadBandwidth,
                    valueFormat: { "\($0)%" }
                )
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
            } footer: {
                VStack(alignment: .leading) {
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
