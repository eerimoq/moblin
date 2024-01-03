import SwiftUI

struct GameControllerButtonSettingsView: View {
    @EnvironmentObject var model: Model
    var button: SettingsGameControllerButton
    @State var selection: SettingsGameControllerButtonFunction

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(gameControllerButtonFunctions, id: \.self) { function in
                        Text(function.toString())
                    }
                }
                .onChange(of: selection) { function in
                    button.function = function
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Function")
            }
        }
        .navigationTitle("Game controller button")
        .toolbar {
            SettingsToolbar()
        }
    }
}
