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

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $selfieStick.enabled)
                ControllerButtonView(model: model,
                                     functions: SettingsControllerFunction.allCases,
                                     function: $selfieStick.function,
                                     sceneId: $selfieStick.sceneId,
                                     widgetId: $selfieStick.widgetId)
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
