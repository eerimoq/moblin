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
                ForEach(0..<model.numberOfScenes, id: \.self) { index in
                    NavigationLink(destination: SceneSettingsView(index: index, model: model)) {
                        Toggle(database.scenes[index].name, isOn: Binding(get: {
                            database.scenes[index].enabled
                        }, set: { value in
                            database.scenes[index].enabled = value
                            model.store()
                            model.resetSelectedScene()
                        }))
                    }
                }.onDelete(perform: { offsets in
                    database.scenes.remove(atOffsets: offsets)
                    model.store()
                    model.resetSelectedScene()
                    model.numberOfScenes -= 1
                })
                CreateButtonView(action: {
                    database.scenes.append(SettingsScene(name: "My scene"))
                    model.store()
                    model.numberOfScenes += 1
                })
            }
            Section("Widgets") {
                ForEach(0..<model.numberOfWidgets, id: \.self) { index in
                    NavigationLink(destination: WidgetSettingsView(index: index, model: model)) {
                        Text(database.widgets[index].name)
                    }
                }.onDelete(perform: { offsets in
                    database.widgets.remove(atOffsets: offsets)
                    model.store()
                    model.numberOfWidgets -= 1
                })
                CreateButtonView(action: {
                    database.widgets.append(SettingsWidget(name: "My widget"))
                    model.store()
                    model.numberOfWidgets += 1
                })
            }
            Section("Variables") {
                ForEach(0..<model.numberOfVariables, id: \.self) { index in
                    NavigationLink(destination: VariableSettingsView(index: index, model: model)) {
                        Text(database.variables[index].name )
                    }
                }.onDelete(perform: { offsets in
                    database.variables.remove(atOffsets: offsets)
                    model.store()
                    model.numberOfVariables -= 1
                })
                CreateButtonView(action: {
                    database.variables.append(SettingsVariable(name: "My variable"))
                    model.store()
                    model.numberOfVariables += 1
                })
            }
        }
        .navigationTitle("Scenes")
    }
}

struct ScenesSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ScenesSettingsView(model: Model())
    }
}
