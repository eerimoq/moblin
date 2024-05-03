import SwiftUI

struct DebugBeautyFilterSettingsView: View {
    @EnvironmentObject var model: Model
    @State var brightness: Float
    @State var contrast: Float
    @State var saturation: Float

    private var settings: SettingsDebugBeautyFilter {
        model.database.debug!.beautyFilterSettings!
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    settings.showColors
                }, set: { value in
                    settings.showColors = value
                    model.store()
                    model.updateBeautyFilterSettings()
                }))
                HStack {
                    Text("Brightness")
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
                }
                HStack {
                    Text("Contrast")
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
                }
                HStack {
                    Text("Saturation")
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
                }
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
        }
        .navigationTitle("Beauty filter")
        .toolbar {
            SettingsToolbar()
        }
    }
}
