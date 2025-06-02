import SwiftUI

struct SelfieStickSettingsView: View {
    @EnvironmentObject var model: Model
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
            } header: {
                Text("Button")
            } footer: {
                Text("⚠️ Hijacks volume buttons. You can only change volume in Control Center when enabled.")
            }
        }
        .navigationTitle("Selfie stick")
    }
}
