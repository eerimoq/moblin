import SwiftUI

struct StreamVideoCaptureSessionPresetSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    var stream: SettingsStream
    @State private var selection: String

    init(model: Model, stream: SettingsStream, toolbar: Toolbar) {
        self.model = model
        self.stream = stream
        self.toolbar = toolbar
        selection = stream.captureSessionPreset!.rawValue
    }

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
                    if stream.captureSessionPresetEnabled! {
                        model.reloadStreamIfEnabled(stream: stream)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Resolution")
        .toolbar {
            toolbar
        }
    }
}
