import SwiftUI

struct StreamVideoCaptureSessionPresetSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var selection: String

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(captureSessionPresets, id: \.self) { preset in
                        Text(preset)
                    }
                }
                .onChange(of: selection) { preset in
                    stream
                        .captureSessionPreset =
                        SettingsCaptureSessionPreset(rawValue: preset)!
                    if stream.captureSessionPresetEnabled {
                        model.storeAndReloadStreamIfEnabled(stream: stream)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Preset")
        .toolbar {
            SettingsToolbar()
        }
    }
}
