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
                    NavigationLink {
                        SceneSettingsView(scene: scene, name: scene.name, selectedRotation: scene.videoSourceRotation!)
                    } label: {
                        HStack {
                            DraggableItemPrefixView()
                            Toggle(scene.name, isOn: Binding(get: {
                                scene.enabled
                            }, set: { value in
                                scene.enabled = value
                                model.resetSelectedScene(changeScene: false)
                            }))
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(action: {
                            database.scenes.removeAll { $0 == scene }
                            model.resetSelectedScene()
                        }, label: {
                            Text("Delete")
                        })
                        .tint(.red)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(action: {
                            database.scenes.append(scene.clone())
                            model.resetSelectedScene(changeScene: false)
                        }, label: {
                            Text("Duplicate")
                        })
                        .tint(.blue)
                    }
                }
                .onMove(perform: { froms, to in
                    database.scenes.move(fromOffsets: froms, toOffset: to)
                    model.resetSelectedScene(changeScene: false)
                })
            }
            CreateButtonView {
                database.scenes.append(SettingsScene(name: String(localized: "My scene")))
                model.resetSelectedScene(changeScene: false)
            }
        } header: {
            Text("Scenes")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a scene"))
        }
    }
}

struct ScenesSettingsView: View {
    // private func onBrbScene(mode _: String) {}

    var body: some View {
        Form {
            ScenesListView()
            WidgetsSettingsView()
        }
        .navigationTitle("Scenes")
    }
}
