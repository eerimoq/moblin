import SwiftUI

private struct ValueView: View {
    let name: LocalizedStringKey
    @Binding var value: Float

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text("\(formatOneDecimal(value.toDegrees()))°")
            Button {
                value -= Float(0.1).toRadians()
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title)
            }
            .buttonStyle(.borderless)
            Button {
                value += Float(0.1).toRadians()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title)
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct GimbalPresetView: View {
    @ObservedObject var gimbal: SettingsGimbal
    @ObservedObject var preset: SettingsGimbalPreset

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $preset.name, existingNames: gimbal.presets)
                }
                Section {
                    ValueView(name: "X", value: $preset.x)
                    ValueView(name: "Y", value: $preset.y)
                }
            }
            .navigationTitle("Preset")
        } label: {
            Text(preset.name)
        }
    }
}

struct GimbalSettingsView: View {
    let model: Model
    @ObservedObject var gimbal: SettingsGimbal

    private func functions() -> [SettingsControllerFunction] {
        return SettingsControllerFunction.allCases.filter {
            ![.unused, .zoomIn, .zoomOut].contains($0)
        }
    }

    private func deletePreset(at offsets: IndexSet) {
        gimbal.presets.remove(atOffsets: offsets)
    }

    var body: some View {
        Form {
            Section {
                Text("Control Moblin with gimbals that supports DockKit.")
            }
            Section {
                HStack {
                    Text("Speed")
                    Slider(value: $gimbal.zoomSpeed, in: 10 ... 100, step: 1)
                    Text(String(Int(gimbal.zoomSpeed)))
                        .frame(width: 30)
                }
                Toggle("Natural", isOn: $gimbal.naturalZoom)
            } header: {
                Text("Zoom")
            }
            Section {
                ControllerButtonView(model: model,
                                     functions: functions(),
                                     function: $gimbal.functionShutter,
                                     sceneId: $gimbal.shutterSceneId,
                                     widgetId: $gimbal.shutterWidgetId,
                                     gimbalPresetId: $gimbal.shutterGimbalPresetId,
                                     gimbalMotion: $gimbal.motion)
            } header: {
                Text("Shutter button")
            }
            Section {
                ControllerButtonView(model: model,
                                     functions: functions(),
                                     function: $gimbal.functionFlip,
                                     sceneId: $gimbal.flipSceneId,
                                     widgetId: $gimbal.flipWidgetId,
                                     gimbalPresetId: $gimbal.flipGimbalPresetId,
                                     gimbalMotion: $gimbal.motion)
            } header: {
                Text("Flip button")
            }
            Section {
                List {
                    ForEach(gimbal.presets) { preset in
                        GimbalPresetView(gimbal: gimbal, preset: preset)
                            .contextMenuDeleteButton {
                                if let offsets = makeOffsets(gimbal.presets, preset.id) {
                                    deletePreset(at: offsets)
                                }
                            }
                    }
                    .onDelete(perform: deletePreset)
                }
                if #available(iOS 18, *) {
                    TextButtonView("Save current") {
                        Task { @MainActor in
                            if let angles = await Gimbal.shared?.getCurrentOrientation() {
                                let preset = SettingsGimbalPreset()
                                preset.name = makeUniqueName(name: SettingsGimbalPreset.baseName,
                                                             existingNames: gimbal.presets)
                                preset.x = Float(angles.x)
                                preset.y = Float(angles.y)
                                gimbal.presets.append(preset)
                            }
                        }
                    }
                    .disabled(Gimbal.shared?.isConnected() != true)
                }
            } header: {
                Text("Presets")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "preset"))
            }
        }
        .navigationTitle("Gimbal")
    }
}
