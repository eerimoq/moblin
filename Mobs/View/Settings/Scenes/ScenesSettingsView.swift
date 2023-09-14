import SwiftUI

struct ScenesSettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        model.database
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
                })
                CreateButtonView(action: {
                    database.scenes.append(SettingsScene(name: "My scene"))
                    model.store()
                    model.resetSelectedScene()
                })
            }
            Section {
                NavigationLink(destination: WidgetsSettingsView(model: model)) {
                    Text("Widgets")
                }
                NavigationLink(destination: ButtonsSettingsView(model: model)) {
                    Text("Buttons")
                }
            }
        }
        .navigationTitle("Scenes")
    }
}
