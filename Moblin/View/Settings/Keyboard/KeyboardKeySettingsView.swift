import SwiftUI

struct KeyboardKeySettingsView: View {
    @EnvironmentObject var model: Model
    var key: SettingsKeyboardKey
    @State var selection: String
    @State var sceneSelection: UUID
    @State var widgetSelection: UUID

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
            if key.function == .widget {
                Section {
                    Picker("", selection: $widgetSelection) {
                        ForEach(model.database.widgets) { widget in
                            Text(widget.name)
                                .tag(widget.id)
                        }
                    }
                    .onChange(of: widgetSelection) { widgetId in
                        key.widgetId = widgetId
                        model.objectWillChange.send()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Widget")
                }
            }
        }
        .navigationTitle("Game controller button")
    }
}
