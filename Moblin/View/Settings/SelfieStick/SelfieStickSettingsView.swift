import SwiftUI

struct SelfieStickDoesNotWorkView: View {
    @ObservedObject var database: Database
    @ObservedObject var selfieStick: SettingsSelfieStick

    var body: some View {
        if database.cameraControlsEnabled, selfieStick.buttonEnabled {
            Text("⚠️ Selfie stick button does not work with Camera controls enabled.")
        }
    }
}

struct SelfieStickSettingsView: View {
    @ObservedObject var database: Database
    @ObservedObject var selfieStick: SettingsSelfieStick

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $selfieStick.buttonEnabled)
                Picker(selection: $selfieStick.buttonFunction) {
                    ForEach(SettingsSelfieStickButtonFunction.allCases, id: \.self) { buttonFunction in
                        Text(buttonFunction.toString())
                            .tag(buttonFunction)
                    }
                } label: {
                    Text("Function")
                }
                SelfieStickDoesNotWorkView(database: database, selfieStick: selfieStick)
            } header: {
                Text("Button")
            } footer: {
                Text("⚠️ Hijacks volume buttons. You can only change volume in Control Center when enabled.")
            }
        }
        .navigationTitle("Selfie stick")
    }
}
