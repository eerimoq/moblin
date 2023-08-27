import SwiftUI

struct ScenesSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section {
                ForEach(self.model.scenes, id: \.self) { scene in
                    NavigationLink(destination: SceneSettingsView(model: self.model)) {
                        Toggle(scene, isOn: $model.isSceneOn)
                    }
                }.onDelete(perform: { offsets in
                    self.model.scenes.remove(atOffsets: offsets)
                })
                AddButtonView(action: {
                    self.model.scenes.append("")
                })
            }
            Section("Widgets") {
                ForEach(self.model.widgets, id: \.self) { widget in
                    NavigationLink(destination: WidgetSettingsView(model: self.model)) {
                       Text(widget)
                    }
                }.onDelete(perform: { offsets in
                    self.model.widgets.remove(atOffsets: offsets)
                })
                AddButtonView(action: {
                    self.model.widgets.append("")
                })
            }
            Section("Variables") {
                ForEach(self.model.variables, id: \.self) { variable in
                    NavigationLink(destination: VariableSettingsView(model: self.model)) {
                        Text(variable)
                    }
                }.onDelete(perform: { offsets in
                    self.model.variables.remove(atOffsets: offsets)
                })
                AddButtonView(action: {
                    self.model.variables.append("")
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
