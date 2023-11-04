import SwiftUI

private let audioGenerators = ["Off", "Square wave"]

struct DebugAudioSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Picker("", selection: $model.audioGenerator) {
                    ForEach(audioGenerators, id: \.self) { mode in
                        Text(mode)
                    }
                }
                .onChange(of: model.audioGenerator) { _ in
                    model.setAudioGenerator(generator: model.audioGenerator)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Generator")
            } footer: {
                Text("Use generated audio as source instead of mic.")
            }
        }
        .navigationTitle("Audio")
    }
}
