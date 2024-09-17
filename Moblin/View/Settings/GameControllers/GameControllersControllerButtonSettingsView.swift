import SwiftUI

struct GameControllersControllerButtonSettingsView: View {
    @EnvironmentObject var model: Model
    var button: SettingsGameControllerButton
    @State var selection: String
    @State var sceneSelection: UUID

    private func onFunctionChange(function: String) {
        selection = function
        button.function = SettingsGameControllerButtonFunction.fromString(value: function)
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: InlinePickerView(title: String(localized: "Function"),
                                                             onChange: onFunctionChange,
                                                             items: InlinePickerItem
                                                                 .fromStrings(
                                                                     values: gameControllerButtonFunctions
                                                                 ),
                                                             selectedId: selection))
                {
                    TextItemView(name: String(localized: "Function"), value: selection)
                }
            }
            if button.function == .scene {
                Section {
                    Picker("", selection: $sceneSelection) {
                        ForEach(model.database.scenes) { scene in
                            Text(scene.name)
                                .tag(scene.id)
                        }
                    }
                    .onChange(of: sceneSelection) { sceneId in
                        button.sceneId = sceneId
                        model.objectWillChange.send()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Scene")
                }
            }
        }
        .navigationTitle("Game controller button")
        .toolbar {
            SettingsToolbar()
        }
    }
}
