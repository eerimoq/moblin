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
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
        model.objectWillChange.send()
    }

    private func submitFastIrlPacketsInFlight(value: Float) {
        adaptiveBitrate.fastIrlSettings!.packetsInFlight = Int32(value)
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func submitFastMinimumBitrate(value: Float) {
        adaptiveBitrate.fastIrlSettings!.minimumBitrate = value / 1000
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func submitBitrateIncreaseSpeed(value: Float) {
        adaptiveBitrate.customSettings.pifDiffIncreaseFactor = value
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func formatBitrateIncreaseSpeed(value: Float) -> String {
        return "\(formatBytesPerSecond(speed: Int64(value * 1000)))/sec"
    }

    private func submitBitrateDecreaseSpeed(value: Float) {
        adaptiveBitrate.customSettings.rttDiffHighDecreaseFactor = powf(1 - (value / 100), 0.2)
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func formatBitrateDecreaseSpeed(value: Float) -> String {
        return "\(Int(value)) %/sec"
    }

    private func submitMinimumBitrateDecreaseSpeed(value: Float) {
        adaptiveBitrate.customSettings.rttDiffHighMinimumDecrease = value / 5 / 1000
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func formatMinimumBitrateDecreaseSpeed(value: Float) -> String {
        return "\(formatBytesPerSecond(speed: Int64(value)))/sec"
    }

    private func submitMinimumBitrate(value: Float) {
        adaptiveBitrate.customSettings.minimumBitrate = value / 1000
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func formatMinimumBitrate(value: Float) -> String {
        return formatBytesPerSecond(speed: Int64(value))
    }

    private func submitPacketsInFlight(value: Float) {
        adaptiveBitrate.customSettings.packetsInFlight = Int32(value)
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func formatPacketsInFlight(value: Float) -> String {
        return "\(Int(value))"
    }

    private func submitAllowedRttSpike(value: Float) {
        adaptiveBitrate.customSettings.rttDiffHighAllowedSpike = value
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    private func formatAllowedRttSpike(value: Float) -> String {
        return "\(Int(value))"
    }

    private func submitBelaboxMinimumBitrate(value: Float) {
        adaptiveBitrate.belaboxSettings!.minimumBitrate = value / 1000
        model.store()
        model.updateAdaptiveBitrateSrtIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Algorithm")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        adaptiveBitrate.algorithm.toString()
                    }, set: handleAlgorithmChange)) {
                        ForEach(adaptiveBitrateAlgorithms, id: \.self) {
                            Text($0)
                        }
                    }
                }
            } footer: {
                Text("Use the Fast IRL algorithm unless you know what you are doing!")
            }
            if adaptiveBitrate.algorithm == .fastIrl {
                Section {
                    SliderView(value: Float(adaptiveBitrate.fastIrlSettings!.packetsInFlight),
                               minimum: 200,
                               maximum: 700,
                               step: 10,
                               onSubmit: submitFastIrlPacketsInFlight,
                               width: 70,
                               format: formatPacketsInFlight)
                } header: {
                    Text("Packets in flight decrease threshold")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("""
                        The bitrate will decrease quickly when the number of packets \
                        in flight are above this value.
                        """)
                        Text("200 by default.")
                    }
                }
                Section {
                    SliderView(value: 1000 * adaptiveBitrate.fastIrlSettings!.minimumBitrate!,
                               minimum: 50000,
                               maximum: 2_000_000,
                               step: 50000,
                               onSubmit: submitFastMinimumBitrate,
                               width: 80,
                               format: formatMinimumBitrate)
                } header: {
                    Text("Minimum bitrate")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("The minimum encoder bitrate.")
                        Text("250 Kbps by default.")
                    }
                }
            } else if adaptiveBitrate.algorithm == .customIrl {
                Section {
                    HStack {
                        Text("⚠️")
                        Text("Finding good parameters is hard. You are on you own! =)")
                    }
                }
                Section {
                    SliderView(value: adaptiveBitrate.customSettings.pifDiffIncreaseFactor,
                               minimum: 5,
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
                               maximum: 5000,
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
                               maximum: 1000,
                               step: 5,
                               onSubmit: submitAllowedRttSpike,
                               width: 80,
                               format: formatAllowedRttSpike)
                } header: {
                    Text("Allowed RTT spike")
                } footer: {
                    Text("The maximum allowed RTT spike before decreasing the bitrate")
                }
                Section {
                    SliderView(value: 1000 * adaptiveBitrate.customSettings.minimumBitrate!,
                               minimum: 50000,
                               maximum: 2_000_000,
                               step: 50000,
                               onSubmit: submitMinimumBitrate,
                               width: 80,
                               format: formatMinimumBitrate)
                } header: {
                    Text("Minimum bitrate")
                } footer: {
                    Text("The minimum encoder bitrate.")
                }
            } else if adaptiveBitrate.algorithm == .belabox {
                Section {
                    SliderView(value: 1000 * adaptiveBitrate.belaboxSettings!.minimumBitrate,
                               minimum: 50000,
                               maximum: 2_000_000,
                               step: 50000,
                               onSubmit: submitBelaboxMinimumBitrate,
                               width: 80,
                               format: formatMinimumBitrate)
                } header: {
                    Text("Minimum bitrate")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("The minimum encoder bitrate.")
                        Text("250 Kbps by default.")
                    }
                }
            }
        }
        .navigationTitle("Adaptive bitrate")
        .toolbar {
            SettingsToolbar()
        }
    }
}
