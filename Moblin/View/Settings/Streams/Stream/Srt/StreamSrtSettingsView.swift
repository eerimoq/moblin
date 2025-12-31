import SwiftUI

struct StreamSrtSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream
    @ObservedObject var srt: SettingsStreamSrt

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
        srt.latency = latency
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
        srt.overheadBandwidth = overheadBandwidth
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Latency"),
                    value: String(srt.latency),
                    onChange: changeLatency,
                    onSubmit: submitLatency,
                    keyboardType: .numbersAndPunctuation,
                    valueFormat: { "\($0) ms" }
                )
                .disabled(stream.enabled && model.isLive)
                if srt.implementation == .moblin && srt.latency < 1000 {
                    Text("""
                    ⚠️ The \"Moblin\" implementation does not perform well with low latency. \
                    Select the \"Official\" implementation at the bottom of this page.
                    """)
                }
                NavigationLink {
                    StreamSrtAdaptiveBitrateSettingsView(stream: stream, srt: srt)
                } label: {
                    Toggle("Adaptive bitrate", isOn: $srt.adaptiveBitrateEnabled)
                        .onChange(of: srt.adaptiveBitrateEnabled) { _ in
                            model.reloadStreamIfEnabled(stream: stream)
                        }
                        .disabled(stream.enabled && model.isLive)
                }
                NavigationLink {
                    StreamSrtConnectionPriorityView(stream: stream)
                } label: {
                    Text("Connection priorities")
                }
                switch srt.implementation {
                case .official:
                    Toggle("Max bandwidth follows input", isOn: $srt.maximumBandwidthFollowInput)
                        .onChange(of: srt.maximumBandwidthFollowInput) { _ in
                            model.reloadStreamIfEnabled(stream: stream)
                        }
                        .disabled(stream.enabled && model.isLive)
                    TextEditNavigationView(
                        title: String(localized: "Overhead bandwidth"),
                        value: String(srt.overheadBandwidth),
                        onChange: changeOverheadBandwidth,
                        onSubmit: submitOverheadBandwidth,
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0)%" }
                    )
                    .disabled(stream.enabled && model.isLive)
                case .moblin:
                    EmptyView()
                }
                Toggle("Big packets", isOn: $srt.bigPackets)
                    .onChange(of: srt.bigPackets) { _ in
                        model.reloadStreamIfEnabled(stream: stream)
                    }
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
                Picker("DNS lookup strategy", selection: $srt.dnsLookupStrategy) {
                    ForEach(SettingsDnsLookupStrategy.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .disabled(stream.enabled && model.isLive)
            } footer: {
                Text("System seems to work best for TMobile. IPv4 probably best for IRLToolkit.")
            }
            Section {
                Picker("Implementation", selection: $srt.implementation) {
                    ForEach(SettingsStreamSrtImplementation.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                .disabled(stream.enabled && model.isLive)
                .onChange(of: srt.implementation) { _ in
                    model.reloadStreamIfEnabled(stream: stream)
                }
            } footer: {
                Text("""
                \"Official\" uses the widely supported libSRT (version 1.5.3) and \"Moblin\" uses a \
                more energy efficient custom implementation.
                """)
            }
        }
        .navigationTitle("SRT(LA)")
    }
}
