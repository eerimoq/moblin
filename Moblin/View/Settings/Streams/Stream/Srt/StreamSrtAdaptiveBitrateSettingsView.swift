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
                    Text("Decrease threshold: 50-500 pkts")
                    Text("Increase speed: 25-500 Kbps/sec")
                } header: {
                    Text("Packets in flight")
                }
                Section {
                    Text("Decrease speed: 5-50 %/sec")
                    Text("Allowed spike: 50-200 ms")
                    Text("Minimum decrease: 25-1250 Kbps/sec")
                } header: {
                    Text("Round trip time (RTT)")
                }
            }
        }
        .navigationTitle("Adaptive bitrate")
        .toolbar {
            SettingsToolbar()
        }
    }
}
