import SwiftUI

struct ScenesSettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.settings.database
        }
    }

    var body: some View {
        Form {
            Section {
                ForEach(database.scenes) { scene in
                    NavigationLink(destination: SceneSettingsView(scene: scene, model: model)) {
                        Toggle(scene.name, isOn: Binding(get: {
                            scene.enabled
                        }, set: { value in
                            scene.enabled = value
                            model.store()
                            model.resetSelectedScene()
                        }))
                    }
                }
                .onDelete(perform: { offsets in
                    database.scenes.remove(atOffsets: offsets)
                    model.store()
                    model.resetSelectedScene()
                    model.objectWillChange.send()
                })
                CreateButtonView(action: {
                    database.scenes.append(SettingsScene(name: "My scene"))
                    model.store()
                    model.objectWillChange.send()
                })
            }
            Section("Widgets") {
                ForEach(database.widgets) { widget in
                    NavigationLink(destination: WidgetSettingsView(widget: widget, model: model)) {
                        Text(widget.name)
                    }
                }
                .onDelete(perform: { offsets in
                    database.widgets.remove(atOffsets: offsets)
                    model.store()
                    model.objectWillChange.send()
                })
                CreateButtonView(action: {
                    database.widgets.append(SettingsWidget(name: "My widget"))
                    model.store()
                    model.objectWillChange.send()
                })
            }
            Section("Variables") {
                ForEach(database.variables) { variable in
                    NavigationLink(destination: VariableSettingsView(variable: variable, model: model)) {
                        Text(variable.name)
                    }
                }
                .onDelete(perform: { offsets in
                    database.variables.remove(atOffsets: offsets)
                    model.store()
                    model.objectWillChange.send()
                })
                CreateButtonView(action: {
                    database.variables.append(SettingsVariable(name: "My variable"))
                    model.store()
                    model.objectWillChange.send()
                })
            }
        }
        .navigationTitle("Scenes")
    }
}
