import SwiftUI

private struct AutoSwitcherSceneSettingsView: View {
    @EnvironmentObject var model: Model
    var scene: SettingsAutoSceneSwitcherScene
    @Binding var sceneId: UUID?
    @Binding var sceneName: String
    @Binding var time: Int

    var body: some View {
        Form {
            Section {
                Picker(selection: $sceneId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(model.database.scenes) { scene in
                        Text(scene.name)
                            .tag(scene.id as UUID?)
                    }
                } label: {
                    Text("Scene")
                }
                .onChange(of: sceneId) { _ in
                    scene.sceneId = sceneId
                    if let sceneId {
                        sceneName = model.getSceneName(id: sceneId)
                    } else {
                        sceneName = "-- None --"
                    }
                }
                Picker(selection: $time) {
                    ForEach([5, 10, 15, 30, 60, 120], id: \.self) { time in
                        Text("\(time)s")
                    }
                } label: {
                    Text("Time")
                }
                .onChange(of: time) { _ in
                    scene.time = time
                }
            }
        }
    }
}

private struct AutoSwitcherSceneSettingsItemView: View {
    @EnvironmentObject var model: Model
    var scene: SettingsAutoSceneSwitcherScene
    @State var sceneId: UUID?
    @State var sceneName: String
    @State var time: Int

    var body: some View {
        NavigationLink {
            AutoSwitcherSceneSettingsView(scene: scene, sceneId: $sceneId, sceneName: $sceneName, time: $time)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(sceneName)
                Spacer()
                Text("\(time)s")
            }
        }
    }
}

private struct AutoSwitcherScenesSettingsView: View {
    @EnvironmentObject var model: Model
    var autoSwitcher: SettingsAutoSceneSwitcher

    var database: Database {
        model.database
    }

    private func getSceneName(sceneId: UUID?) -> String {
        if let sceneId {
            return model.getSceneName(id: sceneId)
        } else {
            return "-- None --"
        }
    }

    var body: some View {
        Section {
            ForEach(autoSwitcher.scenes) { scene in
                AutoSwitcherSceneSettingsItemView(
                    scene: scene,
                    sceneId: scene.sceneId,
                    sceneName: getSceneName(sceneId: scene.sceneId),
                    time: scene.time
                )
            }
            .onMove(perform: { froms, to in
                autoSwitcher.scenes.move(fromOffsets: froms, toOffset: to)
            })
            .onDelete(perform: { offsets in
                autoSwitcher.scenes.remove(atOffsets: offsets)
            })
            CreateButtonView {
                autoSwitcher.scenes.append(SettingsAutoSceneSwitcherScene())
                model.objectWillChange.send()
            }
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a scene"))
        }
    }
}

private struct AutoSwitcherSettingsView: View {
    @EnvironmentObject var model: Model
    var autoSwitcher: SettingsAutoSceneSwitcher
    @Binding var name: String

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    NameEditView(name: $name)
                } label: {
                    TextItemView(name: String(localized: "Name"), value: name)
                }
                .onChange(of: name) { name in
                    autoSwitcher.name = name
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    autoSwitcher.shuffle
                }, set: {
                    autoSwitcher.shuffle = $0
                })) {
                    Text("Shuffle")
                }
            }
            AutoSwitcherScenesSettingsView(autoSwitcher: autoSwitcher)
        }
        .navigationTitle("Auto scene switcher")
    }
}

private struct AutoSwitcherSettingsItemView: View {
    @EnvironmentObject var model: Model
    var autoSwitcher: SettingsAutoSceneSwitcher
    @State var name: String

    var body: some View {
        NavigationLink {
            AutoSwitcherSettingsView(autoSwitcher: autoSwitcher, name: $name)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(name)
                Spacer()
            }
        }
    }
}

struct AutoSwitchersSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Section {
            ForEach(database.autoSceneSwitchers!.switchers) { autoSwitcher in
                AutoSwitcherSettingsItemView(autoSwitcher: autoSwitcher, name: autoSwitcher.name)
            }
            .onMove(perform: { froms, to in
                database.autoSceneSwitchers!.switchers.move(fromOffsets: froms, toOffset: to)
            })
            .onDelete(perform: { offsets in
                database.autoSceneSwitchers!.switchers.remove(atOffsets: offsets)
            })
            CreateButtonView {
                database.autoSceneSwitchers!.switchers.append(SettingsAutoSceneSwitcher())
                model.objectWillChange.send()
            }
        } header: {
            Text("Auto scene switchers")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "an auto scene switcher"))
        }
    }
}
