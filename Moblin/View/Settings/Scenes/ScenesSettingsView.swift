import SwiftUI

private struct ScenesListView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Section {
            List {
                ForEach(database.scenes) { scene in
                    NavigationLink(destination: SceneSettingsView(scene: scene)) {
                        HStack {
                            DraggableItemPrefixView()
                            Toggle(scene.name, isOn: Binding(get: {
                                scene.enabled
                            }, set: { value in
                                scene.enabled = value
                                model.store()
                                model.resetSelectedScene()
                            }))
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(action: {
                            database.scenes.removeAll { $0 == scene }
                            model.store()
                            model.resetSelectedScene()
                        }, label: {
                            Text("Delete")
                        })
                        .tint(.red)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(action: {
                            database.scenes.append(scene.clone())
                            model.store()
                            model.resetSelectedScene()
                        }, label: {
                            Text("Duplicate")
                        })
                        .tint(.blue)
                    }
                }
                .onMove(perform: { froms, to in
                    database.scenes.move(fromOffsets: froms, toOffset: to)
                    model.store()
                    model.resetSelectedScene()
                })
            }
            CreateButtonView(action: {
                database.scenes.append(SettingsScene(name: String(localized: "My scene")))
                model.store()
                model.resetSelectedScene()
            })
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a scene"))
        }
    }
}

struct ScenesSettingsView: View {
    var body: some View {
        Form {
            ScenesListView()
            Section {
                NavigationLink(destination: WidgetsSettingsView()) {
                    Text("Widgets")
                }
            }
        }
        .navigationTitle("Scenes")
        .toolbar {
            SettingsToolbar()
        }
    }
}
