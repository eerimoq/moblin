import SwiftUI

private struct SceneItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene

    var body: some View {
        NavigationLink {
            SceneSettingsView(
                scene: scene,
                selectedRotation: scene.videoSourceRotation,
                numericInput: model.database.sceneNumericInput
            )
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
            Button {
                database.scenes.removeAll { $0 == scene }
                model.resetSelectedScene()
            } label: {
                Text("Delete")
            }
            .tint(.red)
        }
        .swipeActions(edge: .trailing) {
            Button {
                database.scenes.append(scene.clone())
                model.resetSelectedScene()
            } label: {
                Text("Duplicate")
            }
            .tint(.blue)
        }
    }
}

private struct ScenesListView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Section {
            List {
                ForEach(database.scenes) { scene in
                    SceneItemView(database: database, scene: scene)
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
    @State var sceneSwitchTransition: SettingsSceneSwitchTransition

    var body: some View {
        Section {
            Picker("Scene switch transition", selection: $sceneSwitchTransition) {
                ForEach(SettingsSceneSwitchTransition.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: sceneSwitchTransition) { _ in
                model.database.sceneSwitchTransition = sceneSwitchTransition
                model.setSceneSwitchTransition()
            }
            Toggle("Force scene switch transition", isOn: Binding(get: {
                model.database.forceSceneSwitchTransition
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
            ScenesListView(database: model.database)
            WidgetsSettingsView(database: model.database)
            AutoSwitchersSettingsView(autoSceneSwitchers: model.database.autoSceneSwitchers)
            ScenesSwitchTransition(sceneSwitchTransition: model.database.sceneSwitchTransition)
            RemoteSceneView(selectedSceneId: model.database.remoteSceneId)
            ReloadBrowserSources()
        }
        .navigationTitle("Scenes")
    }
}
