import SwiftUI

struct GameControllersControllerButtonSettingsView: View {
    @EnvironmentObject var model: Model
    var button: SettingsGameControllerButton
    @State var selection: SettingsGameControllerButtonFunction
    @State var sceneSelection: UUID

    private func onFunctionChange(function: String) {
        selection = SettingsGameControllerButtonFunction(rawValue: function) ?? .unused
        button.function = selection
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Function"),
                        onChange: onFunctionChange,
                        items: SettingsGameControllerButtonFunction.allCases.map { .init(
                            id: $0.rawValue,
                            text: $0.toString()
                        ) },
                        selectedId: selection.rawValue
                    )
                } label: {
                    TextItemView(name: String(localized: "Function"), value: selection.toString())
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
    }
}
