import SwiftUI

struct ScenesSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section {
                ForEach(0..<self.model.numberOfScenes, id: \.self) { index in
                    NavigationLink(destination: SceneSettingsView(index: index, model: self.model)) {
                        Toggle(self.model.settings.database.scenes[index].name, isOn: Binding(get: {
                            self.model.settings.database.scenes[index].enabled
                        }, set: { _ in
                            self.model.settings.database.scenes[index].enabled.toggle()
                            self.model.settings.store()
                        }))
                    }
                }.onDelete(perform: { offsets in
                    self.model.settings.database.scenes.remove(atOffsets: offsets)
                    self.model.settings.store()
                    self.model.numberOfScenes -= 1
                })
                AddButtonView(action: {
                    self.model.settings.database.scenes.append(SettingsScene(name: ""))
                    self.model.settings.store()
                    self.model.numberOfScenes += 1
                })
            }
            Section("Widgets") {
                ForEach(0..<self.model.numberOfWidgets, id: \.self) { index in
                    NavigationLink(destination: WidgetSettingsView(index: index, model: self.model)) {
                        Text(self.model.settings.database.widgets[index].name)
                    }
                }.onDelete(perform: { offsets in
                    self.model.settings.database.widgets.remove(atOffsets: offsets)
                    self.model.settings.store()
                    self.model.numberOfWidgets -= 1
                })
                AddButtonView(action: {
                    self.model.settings.database.widgets.append(SettingsWidget(name: ""))
                    self.model.settings.store()
                    self.model.numberOfWidgets += 1
                })
            }
            Section("Variables") {
                ForEach(0..<self.model.numberOfVariables, id: \.self) { index in
                    NavigationLink(destination: VariableSettingsView(index: index, model: self.model)) {
                        Text(self.model.settings.database.variables[index].name )
                    }
                }.onDelete(perform: { offsets in
                    self.model.settings.database.variables.remove(atOffsets: offsets)
                    self.model.settings.store()
                    self.model.numberOfVariables -= 1
                })
                AddButtonView(action: {
                    self.model.settings.database.variables.append(SettingsVariable(name: ""))
                    self.model.settings.store()
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
