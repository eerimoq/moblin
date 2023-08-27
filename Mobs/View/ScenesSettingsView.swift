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
                ForEach(0..<self.model.numberOfScenes, id: \.self) { index in
                    NavigationLink(destination: SceneSettingsView(index: index, model: self.model)) {
                        Toggle(database.scenes[index].name, isOn: Binding(get: {
                            database.scenes[index].enabled
                        }, set: { value in
                            database.scenes[index].enabled = value
                            self.model.store()
                        }))
                    }
                }.onDelete(perform: { offsets in
                    database.scenes.remove(atOffsets: offsets)
                    self.model.store()
                    self.model.numberOfScenes -= 1
                })
                CreateButtonView(action: {
                    database.scenes.append(SettingsScene(name: "My scene"))
                    self.model.store()
                    self.model.numberOfScenes += 1
                })
            }
            Section("Widgets") {
                ForEach(0..<self.model.numberOfWidgets, id: \.self) { index in
                    NavigationLink(destination: WidgetSettingsView(index: index, model: self.model)) {
                        Text(database.widgets[index].name)
                    }
                }.onDelete(perform: { offsets in
                    database.widgets.remove(atOffsets: offsets)
                    self.model.store()
                    self.model.numberOfWidgets -= 1
                })
                CreateButtonView(action: {
                    database.widgets.append(SettingsWidget(name: "My widget"))
                    self.model.store()
                    self.model.numberOfWidgets += 1
                })
            }
            Section("Variables") {
                ForEach(0..<self.model.numberOfVariables, id: \.self) { index in
                    NavigationLink(destination: VariableSettingsView(index: index, model: self.model)) {
                        Text(database.variables[index].name )
                    }
                }.onDelete(perform: { offsets in
                    database.variables.remove(atOffsets: offsets)
                    self.model.store()
                    self.model.numberOfVariables -= 1
                })
                CreateButtonView(action: {
                    database.variables.append(SettingsVariable(name: "My variable"))
                    self.model.store()
                    self.model.numberOfVariables += 1
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
