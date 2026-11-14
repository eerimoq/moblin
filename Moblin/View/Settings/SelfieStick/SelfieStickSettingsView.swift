import SwiftUI

struct SelfieStickDoesNotWorkView: View {
    @ObservedObject var database: Database
    @ObservedObject var selfieStick: SettingsSelfieStick

    var body: some View {
        if database.cameraControlsEnabled, selfieStick.enabled {
            Text("⚠️ Selfie stick button does not work with Camera controls enabled.")
        }
    }
}

struct SelfieStickSettingsView: View {
    let model: Model
    @ObservedObject var selfieStick: SettingsSelfieStick

    private func functions() -> [SettingsControllerFunction] {
        SettingsControllerFunction.allCases.filter {
            ![.unused, .zoomIn, .zoomOut].contains($0)
        }
    }

    var body: some View {
        Form {
            Section {
                TradingCardView(name: "SelfieStick",
                                background: Color(red: 0xD2 / 255, green: 0xE0 / 255, blue: 0xD8 / 255))
            }
            Section {
                Toggle("Enabled", isOn: $selfieStick.enabled)
                ControllerButtonView(model: model,
                                     functions: functions(),
                                     function: $selfieStick.function,
                                     functionData: $selfieStick.functionData)
                SelfieStickDoesNotWorkView(database: model.database, selfieStick: selfieStick)
            } header: {
                Text("Button")
            } footer: {
                Text("⚠️ Hijacks volume buttons. You can only change volume in Control Center when enabled.")
            }
        }
        .navigationTitle("Selfie stick")
    }
}
