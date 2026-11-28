import SwiftUI

private struct MicProcessingView: View {
    let model: Model
    @ObservedObject var mic: SettingsMicsMic

    var body: some View {
        Picker(mic.name, selection: $mic.processing) {
            ForEach(SettingsMicsMicProcessing.allCases, id: \.self) {
                Text($0.toString())
            }
        }
        .onChange(of: mic.processing) { _ in
            model.updateMixedMics()
        }
    }
}

struct MicsProcessingSettingsView: View {
    let model: Model
    @ObservedObject var mics: SettingsMics

    var body: some View {
        Form {
            Section {
                ForEach(mics.mics) { mic in
                    MicProcessingView(model: model, mic: mic)
                }
            } footer: {
                Text("Voice removes rumble and evens out the level of speech.")
            }
        }
        .navigationTitle("Processing")
    }
}
