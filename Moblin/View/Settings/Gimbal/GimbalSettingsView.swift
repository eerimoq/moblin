import SwiftUI

private struct ZoomValueView: View {
    @ObservedObject var preset: SettingsGimbalPreset
    @Binding var zoomX: Float

    var body: some View {
        HStack {
            Text("Zoom")
            Spacer()
            Text(formatOneDecimal(preset.zoomX))
            Button {
                zoomX = max(0.5, zoomX - 0.1)
            } label: {
                Image(systemName: "minus.circle")
                    .font(.title)
            }
            .buttonStyle(.borderless)
            Button {
                zoomX = min(15, zoomX + 0.1)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.title)
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct GimbalPresetView: View {
    let model: Model
    @ObservedObject var gimbal: SettingsGimbal
    @ObservedObject var preset: SettingsGimbalPreset
    @State private var presentingConfirm: Bool = false
    @State private var moveAllowed: Bool = false
    @State private var x: Float = 0
    @State private var y: Float = 0
    @State private var zoomX: Float = 1

    private func position() -> some View {
        Group {
            PositionButtonView(image: "arrow.up.circle") {
                x += Float(0.1).toRadians()
            }
            HStack {
                PositionButtonView(image: "arrow.left.circle") {
                    y += Float(0.1).toRadians()
                }
                PositionButtonView(image: "arrow.down.circle") {
                    x -= Float(0.1).toRadians()
                }
                PositionButtonView(image: "arrow.right.circle") {
                    y -= Float(0.1).toRadians()
                }
            }
        }
    }

    private func settingChanged() {
        guard x != preset.x || y != preset.y || zoomX != preset.zoomX else {
            return
        }
        if moveAllowed {
            localToSettings()
            model.moveToGimbalPreset(id: preset.id)
        } else {
            presentingConfirm = true
        }
    }

    private func localFromSettings() {
        x = preset.x
        y = preset.y
        zoomX = preset.zoomX
    }

    private func localToSettings() {
        preset.x = x
        preset.y = y
        preset.zoomX = zoomX
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $preset.name, existingNames: gimbal.presets)
                }
                Section {
                    HStack {
                        Text("Position")
                        Spacer()
                        VStack(alignment: .center, spacing: 7) {
                            position()
                        }
                        .font(.title)
                    }
                    .buttonStyle(.borderless)
                }
                .onChange(of: x) { _ in
                    settingChanged()
                }
                .onChange(of: y) { _ in
                    settingChanged()
                }
                Section {
                    ZoomValueView(preset: preset, zoomX: $zoomX)
                }
                .onChange(of: zoomX) { _ in
                    settingChanged()
                }
                .confirmationDialog("Beware, changing settings will move the Gimbal to the new position.",
                                    isPresented: $presentingConfirm,
                                    titleVisibility: .visible)
                {
                    Button("Ok", role: .destructive) {
                        moveAllowed = true
                        settingChanged()
                    }
                }
                .onChange(of: presentingConfirm) { _ in
                    guard !presentingConfirm, !moveAllowed else {
                        return
                    }
                    localFromSettings()
                }
                .onAppear {
                    moveAllowed = false
                    localFromSettings()
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
                                     gimbalMotion: $gimbal.motion,
                                     macroId: $gimbal.macroId)
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
                                     gimbalMotion: $gimbal.motion,
                                     macroId: $gimbal.macroId)
            } header: {
                Text("Flip button")
            }
            Section {
                List {
                    ForEach(gimbal.presets) { preset in
                        GimbalPresetView(model: model, gimbal: gimbal, preset: preset)
                            .contextMenuDeleteButton {
                                if let offsets = makeOffsets(gimbal.presets, preset.id) {
                                    deletePreset(at: offsets)
                                }
                            }
                    }
                    .onDelete(perform: deletePreset)
                }
                if #available(iOS 18, *) {
                    TextButtonView("Save current position") {
                        model.saveGimbalPreset(id: nil)
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
