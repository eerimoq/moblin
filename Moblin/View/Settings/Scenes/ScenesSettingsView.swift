import SwiftUI

struct ScenesSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Form {
            Section {
                ForEach(database.scenes) { scene in
                    NavigationLink(destination: SceneSettingsView(scene: scene)) {
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
                    database.scenes.append(SettingsScene(name: String(localized: "My scene")))
                    model.store()
                    model.resetSelectedScene()
                })
            }
            Section {
                NavigationLink(destination: WidgetsSettingsView(
                )) {
                    Text("Widgets")
                }
                NavigationLink(destination: ButtonsSettingsView(
                )) {
                    Text("Buttons")
                }
            }
        }
        .navigationTitle("Scenes")
        .toolbar {
            SettingsToolbar()
        }
    }
}
