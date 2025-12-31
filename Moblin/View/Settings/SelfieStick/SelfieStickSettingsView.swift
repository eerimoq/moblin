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
    @EnvironmentObject var model: Model
    @ObservedObject var selfieStick: SettingsSelfieStick

    private func onFunctionChange(function: String) {
        selfieStick.buttonFunction = SettingsControllerFunction(rawValue: function) ?? .unused
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $selfieStick.buttonEnabled)
                NavigationLink {
                    InlinePickerView(
                        title: "Function",
                        onChange: onFunctionChange,
                        items: SettingsControllerFunction.allCases.map { .init(
                            id: $0.rawValue,
                            text: $0.toString()
                        ) },
                        selectedId: selfieStick.buttonFunction.rawValue
                    )
                } label: {
                    TextItemLocalizedView(name: "Function", value: selfieStick.buttonFunction.toString())
                }

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
