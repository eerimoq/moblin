import SwiftUI

struct StreamSrtAdaptiveBitrateSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var packetsInFlight: Float

    private var adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate {
        stream.srt.adaptiveBitrate!
    }

    private func handleAlgorithmChange(value: String) {
        adaptiveBitrate.algorithm = SettingsStreamSrtAdaptiveBitrateAlgorithm.fromString(value: value)
        model.store()
        model.setAdaptiveBitrateAlgorithm(algorithm: adaptiveBitrate.algorithm)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: InlinePickerView(
                    title: "Algorithm",
                    onChange: handleAlgorithmChange,
                    items: InlinePickerItem.fromStrings(values: adaptiveBitrateAlgorithms),
                    selectedId: adaptiveBitrate.algorithm.toString()
                )) {
                    TextItemView(
                        name: String(localized: "Algorithm"),
                        value: adaptiveBitrate.algorithm.toString()
                    )
                }
            }
            if adaptiveBitrate.algorithm == .customIrl {
                Section {
                    Text("25-500 Kbps/sec")
                } header: {
                    Text("Bitrate increase speed")
                }
                Section {
                    Text("5-50 %/sec")
                } header: {
                    Text("Bitrate decrease speed")
                }
                Section {
                    Text("50-500 pkts")
                } header: {
                    Text("Packets in flight decrease threshold")
                } footer: {
                    Text("""
                    The bitrate will decrease quickly when the number of packets \
                    in flight are above this value.
                    """)
                }
                Section {
                    Text("Allowed spike: 50-200 ms")
                } header: {
                    Text("Allowed RTT spike")
                } footer: {
                    Text("The maximum allowed RTT spike before decreasing the bitrate")
                }
                Section {
                    Text("25-1250 Kbps/sec")
                } header: {
                    Text("RTT diff minimum decrease")
                } footer: {
                    Text("The minimum rate at which the bitrate will decrease when RTT is too high")
                }
            }
        }
        .navigationTitle("Adaptive bitrate")
        .toolbar {
            SettingsToolbar()
        }
    }
}
