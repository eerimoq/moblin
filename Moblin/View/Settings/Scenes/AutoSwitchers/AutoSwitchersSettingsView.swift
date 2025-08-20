import SwiftUI

private struct AutoSwitcherSceneSettingsView: View {
    let model: Model
    @ObservedObject var scene: SettingsAutoSceneSwitcherScene

    private func getSceneName(sceneId: UUID?) -> String {
        if let sceneId {
            return model.getSceneName(id: sceneId)
        } else {
            return String(localized: "-- None --")
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Picker(selection: $scene.sceneId) {
                        Text("-- None --")
                            .tag(nil as UUID?)
                        ForEach(model.database.scenes) { scene in
                            Text(scene.name)
                                .tag(scene.id as UUID?)
                        }
                    } label: {
                        Text("Scene")
                    }
                    Picker(selection: $scene.time) {
                        ForEach([5, 10, 15, 30, 60, 120], id: \.self) { time in
                            Text("\(time)s")
                        }
                    } label: {
                        Text("Time")
                    }
                }
            }
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(getSceneName(sceneId: scene.sceneId))
                Spacer()
                Text("\(scene.time)s")
            }
        }
    }
}

private struct AutoSwitcherScenesSettingsView: View {
    let model: Model
    @ObservedObject var autoSwitcher: SettingsAutoSceneSwitcher

    var body: some View {
        Section {
            ForEach(autoSwitcher.scenes) { scene in
                AutoSwitcherSceneSettingsView(model: model, scene: scene)
            }
            .onMove { froms, to in
                autoSwitcher.scenes.move(fromOffsets: froms, toOffset: to)
            }
            .onDelete { offsets in
                autoSwitcher.scenes.remove(atOffsets: offsets)
            }
            AddButtonView {
                autoSwitcher.scenes.append(SettingsAutoSceneSwitcherScene())
            }
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a scene"))
        }
    }
}

private struct AutoSwitcherSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers
    @ObservedObject var autoSwitcher: SettingsAutoSceneSwitcher

    var body: some View {
        Form {
            Section {
                NameEditView(name: $autoSwitcher.name, existingNames: autoSceneSwitchers.switchers)
            }
            Section {
                Toggle("Shuffle", isOn: $autoSwitcher.shuffle)
            }
            AutoSwitcherScenesSettingsView(model: model, autoSwitcher: autoSwitcher)
        }
        .navigationTitle("Auto scene switcher")
    }
}

private struct AutoSwitcherSettingsItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers
    @ObservedObject var autoSwitcher: SettingsAutoSceneSwitcher

    var body: some View {
        NavigationLink {
            AutoSwitcherSettingsView(autoSceneSwitchers: autoSceneSwitchers, autoSwitcher: autoSwitcher)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(autoSwitcher.name)
                Spacer()
            }
        }
    }
}

private struct AutoSceneSwitcherItemView: View {
    @ObservedObject var autoSceneSwitcher: SettingsAutoSceneSwitcher

    var body: some View {
        Text(autoSceneSwitcher.name)
            .tag(autoSceneSwitcher.id as UUID?)
    }
}

struct AutoSwitchersSelectView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoSceneSwitcher: AutoSceneSwitcherProvider
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers

    var body: some View {
        Section {
            Picker("Current", selection: $autoSceneSwitcher.currentSwitcherId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(autoSceneSwitchers.switchers) {
                    AutoSceneSwitcherItemView(autoSceneSwitcher: $0)
                }
            }
            .onChange(of: autoSceneSwitcher.currentSwitcherId) {
                model.setAutoSceneSwitcher(id: $0)
            }
        }
    }
}

struct AutoSwitchersView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers
    let showSelector: Bool

    var body: some View {
        Form {
            if showSelector {
                AutoSwitchersSelectView(autoSceneSwitcher: model.autoSceneSwitcher,
                                        autoSceneSwitchers: autoSceneSwitchers)
            }
            Section {
                ForEach(autoSceneSwitchers.switchers) { autoSwitcher in
                    AutoSwitcherSettingsItemView(autoSceneSwitchers: autoSceneSwitchers, autoSwitcher: autoSwitcher)
                }
                .onMove { froms, to in
                    autoSceneSwitchers.switchers.move(fromOffsets: froms, toOffset: to)
                }
                .onDelete { offsets in
                    model.deleteAutoSceneSwitchers(offsets: offsets)
                }
                CreateButtonView {
                    let switcher = SettingsAutoSceneSwitcher()
                    switcher.name = makeUniqueName(name: SettingsAutoSceneSwitcher.baseName,
                                                   existingNames: autoSceneSwitchers.switchers)
                    autoSceneSwitchers.switchers.append(switcher)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "an auto scene switcher"))
            }
        }
        .navigationTitle("Auto scene switchers")
    }
}

struct AutoSwitchersSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers
    let showSelector: Bool

    var body: some View {
        NavigationLink {
            AutoSwitchersView(autoSceneSwitchers: autoSceneSwitchers, showSelector: showSelector)
        } label: {
            Text("Auto scene switchers")
        }
    }
}
