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
                    print("delete scene")
                })
                CreateButtonView()
            }
            Section("Widgets") {
                ForEach(self.model.widgets, id: \.self) { widget in
                    NavigationLink(destination: WidgetSettingsView(model: self.model)) {
                       Text(widget)
                    }
                }.onDelete(perform: { offsets in
                    print("delete widget")
                })
                CreateButtonView()
            }
            Section("Variables") {
                ForEach(self.model.variables, id: \.self) { variable in
                    NavigationLink(destination: VariableSettingsView(model: self.model)) {
                        Text(variable)
                    }
                }.onDelete(perform: { offsets in
                    print("delete variable")
                })
                CreateButtonView()
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
