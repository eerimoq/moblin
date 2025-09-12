import SwiftUI

struct StreamSrtSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debug: SettingsDebug
    let stream: SettingsStream
    @State var dnsLookupStrategy: String

    private func changeLatency(value: String) -> String? {
        guard let latency = Int32(value) else {
            return String(localized: "Not a number")
        }
        guard latency >= 0 else {
            return String(localized: "Too small")
        }
        return nil
    }

    private func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        stream.srt.latency = latency
        model.reloadStreamIfEnabled(stream: stream)
    }

    private func changeOverheadBandwidth(value: String) -> String? {
        guard let overheadBandwidth = Int32(value) else {
            return String(localized: "Not a number")
        }
        guard overheadBandwidth >= 5 else {
            return String(localized: "Too small")
        }
        guard overheadBandwidth <= 100 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitOverheadBandwidth(value: String) {
        guard let overheadBandwidth = Int32(value) else {
            return
        }
        stream.srt.overheadBandwidth = overheadBandwidth
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Latency"),
                    value: String(stream.srt.latency),
                    onChange: changeLatency,
                    onSubmit: submitLatency,
                    footers: [
                        String(localized: """
                        Zero or more milliseconds. Any latency parameter given in the URL \
                        overrides this value.
                        """),
                    ],
                    keyboardType: .numbersAndPunctuation,
                    valueFormat: { "\($0) ms" }
                )
                .disabled(stream.enabled && model.isLive)
                NavigationLink {
                    StreamSrtAdaptiveBitrateSettingsView(stream: stream)
                } label: {
                    Toggle("Adaptive bitrate", isOn: Binding(get: {
                        stream.srt.adaptiveBitrateEnabled
                    }, set: { value in
                        stream.srt.adaptiveBitrateEnabled = value
                        model.reloadStreamIfEnabled(stream: stream)
                    }))
                    .disabled(stream.enabled && model.isLive)
                }
                NavigationLink {
                    StreamSrtConnectionPriorityView(stream: stream)
                } label: {
                    Text("Connection priorities")
                }
                if !debug.newSrt {
                    Toggle("Max bandwidth follows input", isOn: Binding(get: {
                        stream.srt.maximumBandwidthFollowInput
                    }, set: { value in
                        stream.srt.maximumBandwidthFollowInput = value
                        model.reloadStreamIfEnabled(stream: stream)
                    }))
                    .disabled(stream.enabled && model.isLive)
                    TextEditNavigationView(
                        title: String(localized: "Overhead bandwidth"),
                        value: String(stream.srt.overheadBandwidth),
                        onChange: changeOverheadBandwidth,
                        onSubmit: submitOverheadBandwidth,
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0)%" }
                    )
                    .disabled(stream.enabled && model.isLive)
                }
                Toggle("Big packets", isOn: Binding(get: {
                    stream.srt.mpegtsPacketsPerPacket == 7
                }, set: { value in
                    if value {
                        stream.srt.mpegtsPacketsPerPacket = 7
                    } else {
                        stream.srt.mpegtsPacketsPerPacket = 6
                    }
                    model.reloadStreamIfEnabled(stream: stream)
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
            Section {
                Picker("DNS lookup strategy", selection: $dnsLookupStrategy) {
                    ForEach(dnsLookupStrategies, id: \.self) { strategy in
                        Text(strategy)
                    }
                }
                .onChange(of: dnsLookupStrategy) { strategy in
                    stream.srt.dnsLookupStrategy = SettingsDnsLookupStrategy(rawValue: strategy) ?? .system
                }
                .disabled(stream.enabled && model.isLive)
            } footer: {
                Text("System seems to work best for TMobile. IPv4 probably best for IRLToolkit.")
            }
        }
        .navigationTitle("SRT(LA)")
    }
}
