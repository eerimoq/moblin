import SwiftUI

private struct MicOutputView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        Picker(mic.name, selection: $mic.output) {
            ForEach(SettingsMicsMicOutput.allCases, id: \.self) {
                Text($0.toString())
            }
        }
        .onChange(of: mic.output) { _ in
            model.updateMixedMics()
        }
    }
}

struct MicsOutputsSettingsView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics

    var body: some View {
        Form {
            Section {
                ForEach(mics.mics) { mic in
                    MicOutputView(model: model, mic: mic)
                }
            } footer: {
                Text("The audio level shows the stream, and replays use the recording.")
            }
        }
        .navigationTitle("Outputs")
    }
}
