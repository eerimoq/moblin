import HaishinKit
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
            Section {
                HStack {
                    Slider(
                        value: $model.squareWaveGeneratorAmplitude,
                        in: 0 ... 10000,
                        step: 10
                    )
                    .onChange(of: model.squareWaveGeneratorAmplitude) { value in
                        squareWaveGeneratorAmplitude = Int16(value)
                    }
                    Text(String(Int16(model.squareWaveGeneratorAmplitude)))
                        .frame(width: 55)
                }
            } header: {
                Text("Amplitude")
            }
            Section {
                HStack {
                    Slider(
                        value: $model.squareWaveGeneratorInterval,
                        in: 5 ... 500,
                        step: 5
                    )
                    .onChange(of: model.squareWaveGeneratorInterval) { value in
                        squareWaveGeneratorInterval = UInt64(value)
                    }
                    Text(String(UInt64(model.squareWaveGeneratorInterval)))
                        .frame(width: 55)
                }
            } header: {
                Text("Interval")
            }
        }
        .navigationTitle("Audio")
        .toolbar {
            SettingsToolbar()
        }
    }
}
