import SwiftUI

private struct SceneItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene

    var body: some View {
        NavigationLink {
            SceneSettingsView(database: model.database, scene: scene)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Toggle(scene.name, isOn: $scene.enabled)
                    .onChange(of: scene.enabled) { _ in
                        if model.getSelectedScene() === scene {
                            model.resetSelectedScene()
                        } else {
                            model.sceneSelector.sceneIndex += 0
                        }
                    }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                let deletedCurrentScene = model.getSelectedScene() === scene
                database.scenes.removeAll { $0 == scene }
                if deletedCurrentScene {
                    model.resetSelectedScene()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                database.scenes.append(scene.clone())
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
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
                .onMove { froms, to in
                    database.scenes.move(fromOffsets: froms, toOffset: to)
                }
            }
            CreateButtonView {
                let name = makeUniqueName(name: SettingsScene.baseName, existingNames: database.scenes)
                let scene = SettingsScene(name: name)
                database.scenes.append(scene)
            }
        } header: {
            Text("Scenes")
        } footer: {
            SwipeLeftToDuplicateOrDeleteHelpView(kind: String(localized: "a scene"))
        }
    }
}

private struct ScenesSwitchTransition: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Section {
            Picker("Scene switch transition", selection: $database.sceneSwitchTransition) {
                ForEach(SettingsSceneSwitchTransition.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .onChange(of: database.sceneSwitchTransition) { _ in
                model.setSceneSwitchTransition()
            }
            Toggle("Force scene switch transition", isOn: $database.forceSceneSwitchTransition)
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
                HCenter {
                    Text("Reload browser widgets")
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
            AutoSwitchersSettingsView(autoSceneSwitchers: model.database.autoSceneSwitchers, showSelector: true)
            DisconnectProtectionSettingsView(database: model.database,
                                             disconnectProtection: model.database.disconnectProtection)
            ScenesSwitchTransition(database: model.database)
            RemoteSceneView(selectedSceneId: model.database.remoteSceneId)
            ReloadBrowserSources()
        }
        .navigationTitle("Scenes")
    }
}
