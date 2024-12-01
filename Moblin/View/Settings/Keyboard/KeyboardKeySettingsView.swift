import SwiftUI

struct KeyboardKeySettingsView: View {
    @EnvironmentObject var model: Model
    var key: SettingsKeyboardKey
    @State var selection: String
    @State var sceneSelection: UUID

    private func onFunctionChange(function: String) {
        selection = function
        key.function = SettingsKeyboardKeyFunction.fromString(value: function)
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: "Key", value: key.key) {
                    key.key = $0
                }
            }
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Function"),
                        onChange: onFunctionChange,
                        items: InlinePickerItem
                            .fromStrings(values: keyboardKeyFunctions),
                        selectedId: selection
                    )
                } label: {
                    TextItemView(name: String(localized: "Function"), value: selection)
                }
            }
            if key.function == .scene {
                Section {
                    Picker("", selection: $sceneSelection) {
                        ForEach(model.database.scenes) { scene in
                            Text(scene.name)
                                .tag(scene.id)
                        }
                    }
                    .onChange(of: sceneSelection) { sceneId in
                        key.sceneId = sceneId
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
