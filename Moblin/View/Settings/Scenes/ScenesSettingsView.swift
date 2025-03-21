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
                                model.resetSelectedScene()
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
                            model.resetSelectedScene()
                        }, label: {
                            Text("Duplicate")
                        })
                        .tint(.blue)
                    }
                }
                .onMove(perform: { froms, to in
                    database.scenes.move(fromOffsets: froms, toOffset: to)
                    model.resetSelectedScene()
                })
            }
            CreateButtonView {
                database.scenes.append(SettingsScene(name: String(localized: "My scene")))
                model.resetSelectedScene()
            }
        } header: {
            Text("Scenes")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a scene"))
        }
    }
}

private struct ScenesSwitchTransition: View {
    @EnvironmentObject var model: Model
    @State var sceneSwitchTransition: String

    var body: some View {
        Section {
            Picker("Scene switch transition", selection: $sceneSwitchTransition) {
                ForEach(sceneSwitchTransitions, id: \.self) { transition in
                    Text(transition)
                }
            }
            .onChange(of: sceneSwitchTransition) { _ in
                model.database.sceneSwitchTransition = SettingsSceneSwitchTransition
                    .fromString(value: sceneSwitchTransition)
                model.setSceneSwitchTransition()
            }
            Toggle("Force scene switch transition", isOn: Binding(get: {
                model.database.forceSceneSwitchTransition!
            }, set: { value in
                model.database.forceSceneSwitchTransition = value
            }))
        } footer: {
            Text("""
            RTMP, SRT(LA), screen capture and media player video sources can instantly be switched \
            to, but if you want consistency you can force scene switch transitions to these as well.
            """)
        }
    }
}

private struct RemoteSceneView: View {
    @EnvironmentObject var model: Model
    @State var selectedSceneId: UUID?

    var body: some View {
        Section {
            Picker(selection: $selectedSceneId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(model.database.scenes) { scene in
                    Text(scene.name)
                        .tag(scene.id as UUID?)
                }
            } label: {
                Text("Remote scene")
            }
            .onChange(of: selectedSceneId) { _ in
                model.database.remoteSceneId = selectedSceneId
                model.remoteSceneSettingsUpdated()
            }
        } footer: {
            Text("""
            Widgets in selected scene will be shown on the Moblin device the remote control \
            assistant is connected to.
            """)
        }
    }
}

private struct ReloadBrowserSources: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Section {
            Button {
                model.reloadBrowserWidgets()
            } label: {
                HStack {
                    Spacer()
                    Text("Reload browser widgets")
                    Spacer()
                }
            }
        }
    }
}

struct ScenesSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            ScenesListView()
            WidgetsSettingsView()
            ScenesSwitchTransition(sceneSwitchTransition: model.database.sceneSwitchTransition!.toString())
            RemoteSceneView(selectedSceneId: model.database.remoteSceneId)
            ReloadBrowserSources()
        }
        .navigationTitle("Scenes")
    }
}
