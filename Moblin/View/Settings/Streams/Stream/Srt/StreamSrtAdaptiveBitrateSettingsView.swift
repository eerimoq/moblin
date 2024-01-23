import SwiftUI

struct StreamSrtAdaptiveBitrateSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream

    private var adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate {
        stream.srt.adaptiveBitrate!
    }

    private func handleAlgorithmChange(value: String) {
        adaptiveBitrate.algorithm = SettingsStreamSrtAdaptiveBitrateAlgorithm.fromString(value: value)
        model.store()
        model.updateAdaptiveBitrateIfEnabled(stream: stream)
        model.objectWillChange.send()
    }

    private func submitBitrateIncreaseSpeed(value: Float) {
        adaptiveBitrate.customSettings.pifDiffIncreaseFactor = value
        model.store()
        model.updateAdaptiveBitrateIfEnabled(stream: stream)
    }

    private func formatBitrateIncreaseSpeed(value: Float) -> String {
        return "\(formatBytesPerSecond(speed: Int64(value * 1000)))/sec"
    }

    private func submitBitrateDecreaseSpeed(value: Float) {
        adaptiveBitrate.customSettings.rttDiffHighDecreaseFactor = powf(1 - (value / 100), 0.2)
        model.store()
        model.updateAdaptiveBitrateIfEnabled(stream: stream)
    }

    private func formatBitrateDecreaseSpeed(value: Float) -> String {
        return "\(Int(value)) %/sec"
    }

    private func submitMinimumBitrateDecreaseSpeed(value: Float) {
        adaptiveBitrate.customSettings.rttDiffHighMinimumDecrease = value / 5 / 1000
        model.store()
        model.updateAdaptiveBitrateIfEnabled(stream: stream)
    }

    private func formatMinimumBitrateDecreaseSpeed(value: Float) -> String {
        return "\(formatBytesPerSecond(speed: Int64(value)))/sec"
    }

    private func submitPacketsInFlight(value: Float) {
        adaptiveBitrate.customSettings.packetsInFlight = Int32(value)
        model.store()
        model.updateAdaptiveBitrateIfEnabled(stream: stream)
    }

    private func formatPacketsInFlight(value: Float) -> String {
        return "\(Int(value))"
    }

    private func submitAllowedRttSpike(value: Float) {
        adaptiveBitrate.customSettings.rttDiffHighAllowedSpike = value
        model.store()
        model.updateAdaptiveBitrateIfEnabled(stream: stream)
    }

    private func formatAllowedRttSpike(value: Float) -> String {
        return "\(Int(value))"
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
                    SliderView(value: adaptiveBitrate.customSettings.pifDiffIncreaseFactor,
                               minimum: 25,
                               maximum: 500,
                               step: 5,
                               onSubmit: submitBitrateIncreaseSpeed,
                               width: 120,
                               format: formatBitrateIncreaseSpeed)
                } header: {
                    Text("Bitrate increase speed")
                }
                Section {
                    SliderView(
                        value: 100 * (1 - powf(adaptiveBitrate.customSettings.rttDiffHighDecreaseFactor, 5)),
                        minimum: 10,
                        maximum: 50,
                        step: 1,
                        onSubmit: submitBitrateDecreaseSpeed,
                        width: 80,
                        format: formatBitrateDecreaseSpeed
                    )
                } header: {
                    Text("Bitrate decrease speed")
                } footer: {
                    Text("The bitrate decrease speed when RTT is too high.")
                }
                Section {
                    SliderView(value: 5 * 1000 * adaptiveBitrate.customSettings.rttDiffHighMinimumDecrease,
                               minimum: 25000,
                               maximum: 2_000_000,
                               step: 5000,
                               onSubmit: submitMinimumBitrateDecreaseSpeed,
                               width: 120,
                               format: formatMinimumBitrateDecreaseSpeed)
                } header: {
                    Text("Minimum bitrate decrease speed")
                } footer: {
                    Text("The minimum bitrate decrease speed when RTT is too high.")
                }
                Section {
                    SliderView(value: Float(adaptiveBitrate.customSettings.packetsInFlight),
                               minimum: 50,
                               maximum: 500,
                               step: 5,
                               onSubmit: submitPacketsInFlight,
                               width: 100,
                               format: formatPacketsInFlight)
                } header: {
                    Text("Packets in flight decrease threshold")
                } footer: {
                    Text("""
                    The bitrate will decrease quickly when the number of packets \
                    in flight are above this value.
                    """)
                }
                Section {
                    SliderView(value: adaptiveBitrate.customSettings.rttDiffHighAllowedSpike,
                               minimum: 25,
                               maximum: 200,
                               step: 5,
                               onSubmit: submitAllowedRttSpike,
                               width: 80,
                               format: formatAllowedRttSpike)
                } header: {
                    Text("Allowed RTT spike")
                } footer: {
                    Text("The maximum allowed RTT spike before decreasing the bitrate")
                }
            }
        }
        .navigationTitle("Adaptive bitrate")
        .toolbar {
            SettingsToolbar()
        }
    }
}
