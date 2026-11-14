import SwiftUI

private struct MicDelayView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        VStack(alignment: .leading) {
            Text(mic.name)
                .lineLimit(1)
            HStack {
                Slider(value: $mic.delay, in: -0.5 ... 0.5, step: 0.01)
                    .onChange(of: mic.delay) { _ in
                        model.updateMicDelay()
                    }
                Text("\(formatTwoDecimals(mic.delay)) s")
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
                    Text("Use to synchronize audio and video.")
                }
            }
        }
        .navigationTitle("Delays")
    }
}
