import SwiftUI

struct DebugBeautyFilterSettingsView: View {
    @EnvironmentObject var model: Model
    @State var brightness: Float
    @State var contrast: Float
    @State var saturation: Float
    @State var cuteRadius: Float
    @State var cuteScale: Float
    @State var cuteOffset: Float

    private var settings: SettingsDebugBeautyFilter {
        model.database.debug!.beautyFilterSettings!
    }

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
                    settings.showBlur
                }, set: { value in
                    settings.showBlur = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Moblin in mouth", isOn: Binding(get: {
                    settings.showMoblin
                }, set: { value in
                    settings.showMoblin = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Comic", isOn: Binding(get: {
                    settings.showComic
                }, set: { value in
                    settings.showComic = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Face rectangle", isOn: Binding(get: {
                    settings.showFaceRectangle
                }, set: { value in
                    settings.showFaceRectangle = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Face landmarks", isOn: Binding(get: {
                    settings.showFaceLandmarks
                }, set: { value in
                    settings.showFaceLandmarks = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
            }
            Section {
                Toggle("Adjust colors", isOn: Binding(get: {
                    settings.showColors
                }, set: { value in
                    settings.showColors = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
            }
            Section("Brightness") {
                Slider(
                    value: $brightness,
                    in: -0.5 ... 0.5,
                    step: 0.01,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.store()
                    }
                )
                .onChange(of: brightness) { _ in
                    settings.brightness = brightness
                    model.updateBeautyFilterSettings()
                }
                Text(String(brightness))
            }
            Section("Contrast") {
                Slider(
                    value: $contrast,
                    in: 0 ... 2,
                    step: 0.01,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.store()
                    }
                )
                .onChange(of: contrast) { _ in
                    settings.contrast = contrast
                    model.updateBeautyFilterSettings()
                }
                Text(String(contrast))
            }
            Section("Saturation") {
                Slider(
                    value: $saturation,
                    in: 0 ... 2,
                    step: 0.01,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.store()
                    }
                )
                .onChange(of: saturation) { _ in
                    settings.saturation = saturation
                    model.updateBeautyFilterSettings()
                }
                Text(String(saturation))
            }
            Section {
                Toggle("Cute", isOn: Binding(get: {
                    settings.showCute!
                }, set: { value in
                    settings.showCute = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
            }
            Section("Cute radius") {
                Slider(
                    value: $cuteRadius,
                    in: 10 ... 500,
                    step: 5,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.store()
                    }
                )
                .onChange(of: cuteRadius) { _ in
                    settings.cuteRadius = cuteRadius
                    model.updateBeautyFilterSettings()
                }
                Text(String(cuteRadius))
            }
            Section("Cute scale") {
                Slider(
                    value: $cuteScale,
                    in: 0 ... 1,
                    step: 0.01,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.store()
                    }
                )
                .onChange(of: cuteScale) { _ in
                    settings.cuteScale = cuteScale
                    model.updateBeautyFilterSettings()
                }
                Text(String(cuteScale))
            }
            Section("Cute offset") {
                Slider(
                    value: $cuteOffset,
                    in: -300 ... 300,
                    step: 5,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.store()
                    }
                )
                .onChange(of: cuteOffset) { _ in
                    settings.cuteOffset = cuteOffset
                    model.updateBeautyFilterSettings()
                }
                Text(String(cuteOffset))
            }
        }
        .navigationTitle("Beauty filter")
        .toolbar {
            SettingsToolbar()
        }
    }
}
