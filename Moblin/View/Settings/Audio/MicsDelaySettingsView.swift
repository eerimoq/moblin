import SwiftUI

private struct MicDelayView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        let range = makeMicDelayRange(audioMixer: model.database.debug.audioMixer)
        VStack(alignment: .leading) {
            Text(mic.name)
                .lineLimit(1)
            HStack {
                Slider(
                    value: Binding(get: { mic.delay.clamped(to: range) }, set: { mic.delay = $0 }),
                    in: range,
                    step: 0.01,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.updateMicDelay()
                    }
                )
                .onChange(of: mic.delay) { _ in
                    if !model.database.debug.audioMixer {
                        model.updateMicDelay()
                    }
                }
                Text("\(formatTwoDecimals(mic.delay.clamped(to: range))) s")
                    .frame(width: 60)
            }
        }
    }
}

struct MicsDelaySettingsView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics

    var body: some View {
        Form {
            Section {
                ForEach(mics.mics) { mic in
                    MicDelayView(model: model, mic: mic)
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("A positive delay makes the audio later, a negative delay earlier.")
                    Text("")
                    if model.database.debug.audioMixer {
                        Text("Use to synchronize audio and video, and mixed mics with each other.")
                    } else {
                        Text("Use to synchronize audio and video.")
                    }
                }
            }
        }
        .navigationTitle("Delays")
    }
}
