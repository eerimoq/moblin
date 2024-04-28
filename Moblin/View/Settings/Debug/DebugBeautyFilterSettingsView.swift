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
                    model.beautyFilterShowBlur
                }, set: { value in
                    model.beautyFilterShowBlur = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Moblin", isOn: Binding(get: {
                    model.beautyFilterShowMoblin
                }, set: { value in
                    model.beautyFilterShowMoblin = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Comic", isOn: Binding(get: {
                    model.beautyFilterShowComic
                }, set: { value in
                    model.beautyFilterShowComic = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Face rectangle", isOn: Binding(get: {
                    model.beautyFilterShowFaceRectangle
                }, set: { value in
                    model.beautyFilterShowFaceRectangle = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Face landmarks", isOn: Binding(get: {
                    model.beautyFilterShowFaceLandmarks
                }, set: { value in
                    model.beautyFilterShowFaceLandmarks = value
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Adjust colors", isOn: Binding(get: {
                    model.beautyFilterShowColors
                }, set: { value in
                    model.beautyFilterShowColors = value
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
