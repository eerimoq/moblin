import SwiftUI

struct DebugBeautyFilterSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.debug!.beautyFilter!
                }, set: { value in
                    model.database.debug!.beautyFilter = value
                    model.sceneUpdated()
                }))
            }
            Section {
                Toggle("Blur", isOn: Binding(get: {
                    model.beautyFilterBlur
                }, set: { value in
                    model.beautyFilterBlur = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Moblin", isOn: Binding(get: {
                    model.beautyFilterMoblin
                }, set: { value in
                    model.beautyFilterMoblin = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Comic", isOn: Binding(get: {
                    model.beautyFilterComic
                }, set: { value in
                    model.beautyFilterComic = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Adjust colors", isOn: Binding(get: {
                    model.beautyFilterColors
                }, set: { value in
                    model.beautyFilterColors = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section("Brightness") {
                Slider(
                    value: $model.beautyFilterBrightness,
                    in: -0.5 ... 0.5,
                    step: 0.01
                )
                .onChange(of: model.beautyFilterBrightness) { _ in
                    model.updateBeautyFilterSettings()
                }
                Text("\(model.beautyFilterBrightness)")
            }
            Section("Contrast") {
                Slider(
                    value: $model.beautyFilterContrast,
                    in: 0 ... 2,
                    step: 0.01
                )
                .onChange(of: model.beautyFilterContrast) { _ in
                    model.updateBeautyFilterSettings()
                }
                Text("\(model.beautyFilterContrast)")
            }
            Section("Saturation") {
                Slider(
                    value: $model.beautyFilterSaturation,
                    in: 0 ... 2,
                    step: 0.01
                )
                .onChange(of: model.beautyFilterSaturation) { _ in
                    model.updateBeautyFilterSettings()
                }
                Text("\(model.beautyFilterSaturation)")
            }
        }
        .navigationTitle("Beauty filter")
        .toolbar {
            SettingsToolbar()
        }
    }
}
