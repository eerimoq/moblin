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
        }
        .navigationTitle("Gimbal")
    }
}
