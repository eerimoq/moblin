import SwiftUI

private struct MicGainView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        VStack(alignment: .leading) {
            Text(mic.name)
                .lineLimit(1)
            HStack {
                Slider(value: $mic.gainDb, in: -24.0 ... 24.0, step: 1.0)
                    .onChange(of: mic.gainDb) { _ in
                        model.updateAudioGain()
                    }
                Text("\(formatOneDecimal(mic.gainDb)) dB")
                    .frame(width: 65)
            }
        }
    }
}

struct MicsGainSettingsView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics

    var body: some View {
        Form {
            Section {
                ForEach(mics.mics) { mic in
                    MicGainView(model: model, mic: mic)
                }
            } footer: {
                Text("Added to the output gain when the mic is selected.")
            }
        }
        .navigationTitle("Gains")
    }
}
