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
                Text("Control Moblin with Gimbals that supports DockKit.")
            }
            Section {
                ControllerButtonView(model: model,
                                     functions: functions(),
                                     function: $gimbal.functionShutter,
                                     sceneId: $gimbal.shutterSceneId,
                                     widgetId: $gimbal.shutterWidgetId)
            } header: {
                Text("Shutter button")
            }
            Section {
                ControllerButtonView(model: model,
                                     functions: functions(),
                                     function: $gimbal.functionFlip,
                                     sceneId: $gimbal.flipSceneId,
                                     widgetId: $gimbal.flipWidgetId)
            } header: {
                Text("Flip button")
            }
            Section {
                Toggle("Enabled", isOn: $gimbal.zoomSpeedEnabled)
                HStack {
                    Slider(value: $gimbal.zoomSpeed, in: 1.001 ... 1.099, step: 0.001)
                    Text(String(format: "%02d", Int(round((gimbal.zoomSpeed - 1.0) * 1000))))
                        .frame(width: 30)
                }
            } header: {
                Text("Zoom speed")
            } footer: {
                Text("Enable for seemingly bugged DJI gimbals.")
            }
        }
        .navigationTitle("Gimbal")
    }
}
