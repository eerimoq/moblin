import SwiftUI

struct GimbalSettingsView: View {
    let model: Model
    @ObservedObject var gimbal: SettingsGimbal

    private func functions() -> [SettingsControllerFunction] {
        return SettingsControllerFunction.allCases.filter {
            ![.unused, .zoomIn, .zoomOut].contains($0)
        }
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
                                     gimbalOrientationId: $gimbal.shutterGimbalOrientationId)
            } header: {
                Text("Shutter button")
            }
            Section {
                ControllerButtonView(model: model,
                                     functions: functions(),
                                     function: $gimbal.functionFlip,
                                     sceneId: $gimbal.flipSceneId,
                                     widgetId: $gimbal.flipWidgetId,
                                     gimbalOrientationId: $gimbal.flipGimbalOrientationId)
            } header: {
                Text("Flip button")
            }
            Section {
                List {
                    ForEach(gimbal.orientations) {
                        Text($0.name)
                    }
                    .onDelete { offsets in
                        gimbal.orientations.remove(atOffsets: offsets)
                    }
                }
                TextButtonView("Save current") {
                    if #available(iOS 18, *) {
                        Task { @MainActor in
                            if let angles = await Gimbal.shared?.getCurrentOrientation() {
                                let orientation = SettingsGimbalOrientation()
                                orientation.name = makeUniqueName(name: SettingsGimbalOrientation.baseName,
                                                                  existingNames: gimbal.orientations)
                                orientation.x = Float(angles.x)
                                orientation.y = Float(angles.y)
                                gimbal.orientations.append(orientation)
                            }
                        }
                    }
                }
            } header: {
                Text("Orientations")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "orientation"))
            }
        }
        .navigationTitle("Gimbal")
    }
}
