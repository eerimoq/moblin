import SwiftUI

struct WidgetVideoEffectSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var selection: String
    @State var noiseLevel: Float
    @State var sharpness: Float

    var body: some View {
        Section("Video effect") {
            Picker("", selection: $selection) {
                ForEach(videoEffects, id: \.self) { videoEffect in
                    Text(videoEffect)
                }
            }
            .onChange(of: selection) { type in
                widget.videoEffect.type = SettingsWidgetVideoEffectType(rawValue: type)!
                model.resetSelectedScene()
                model.sceneUpdated()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        if widget.videoEffect.type == .noiseReduction {
            Section("Parameters") {
                HStack {
                    Text("Noise level")
                    Text(String(format: "%.03f", noiseLevel / 10))
                    Slider(value: $noiseLevel, onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        widget.videoEffect.noiseReductionNoiseLevel = noiseLevel / 10
                        model.store()
                        model.sceneUpdated()
                    })
                }
                HStack {
                    Text("Sharpness")
                    Text(String(format: "%.02f", sharpness * 10))
                    Slider(value: $sharpness, onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        widget.videoEffect.noiseReductionSharpness = sharpness * 10
                        model.store()
                        model.sceneUpdated()
                    })
                }
            }
        }
    }
}
