import SwiftUI

struct ScenesSettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.database
        }
    }

    func isWidgetUsed(widget: SettingsWidget) -> Bool {
        for scene in database.scenes {
            for sceneWidget in scene.widgets {
                if sceneWidget.widgetId == widget.id {
                    return true
                }
            }
        }
        for button in database.buttons {
            if button.type == "Widget" {
                if button.widget.widgetId == widget.id {
                    return true
                }
            }
        }
        return false
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
                    model.objectWillChange.send()
                })
                CreateButtonView(action: {
                    database.scenes.append(SettingsScene(name: "My scene"))
                    model.store()
                    model.objectWillChange.send()
                })
            }
            Section {
                ForEach(database.widgets) { widget in
                    NavigationLink(destination: WidgetSettingsView(widget: widget, model: model)) {
                        HStack {
                            Image(systemName: widgetImage(widget: widget))
                            Text(widget.name)
                        }
                    }
                    .deleteDisabled(isWidgetUsed(widget: widget))
                }
                .onDelete(perform: { offsets in
                    database.widgets.remove(atOffsets: offsets)
                    model.store()
                    model.objectWillChange.send()
                })
                CreateButtonView(action: {
                    database.widgets.append(SettingsWidget(name: "My widget"))
                    model.store()
                    model.objectWillChange.send()
                })
            } header: {
                Text("Widgets")
            } footer: {
                Text("Only unused widgets can be deleted.")
            }
            Section {
                List {
                    ForEach(database.buttons) { button in
                        NavigationLink(destination: ButtonSettingsView(button: button, model: model)) {
                            HStack {
                                Image(systemName: button.systemImageNameOff)
                                Toggle(button.name, isOn: Binding(get: {
                                    button.enabled
                                }, set: { value in
                                    button.enabled = value
                                    model.store()
                                    model.sceneUpdated()
                                }))
                            }
                        }
                    }
                    .onMove(perform: { (froms, to) in
                        database.buttons.move(fromOffsets: froms, toOffset: to)
                        model.store()
                        model.sceneUpdated()
                    })
                    .onDelete(perform: { offsets in
                        database.buttons.remove(atOffsets: offsets)
                        model.store()
                        model.sceneUpdated()
                    })
                }
                CreateButtonView(action: {
                    let button = SettingsButton(name: "My button")
                    button.enabled = true
                    for scene in model.database.scenes {
                        button.scenes.append(scene.id)
                    }
                    database.buttons.append(button)
                    model.store()
                    model.sceneUpdated()
                })
            } header: {
                Text("Buttons")
            } footer: {
                Text("Buttons appear in given order in the main view.")
            }
            Section {
                ForEach(database.variables) { variable in
                    NavigationLink(destination: VariableSettingsView(variable: variable, model: model)) {
                        Text(variable.name)
                    }
                }
                .onDelete(perform: { offsets in
                    database.variables.remove(atOffsets: offsets)
                    model.store()
                    model.objectWillChange.send()
                })
                CreateButtonView(action: {
                    database.variables.append(SettingsVariable(name: "My variable"))
                    model.store()
                    model.objectWillChange.send()
                })
            } header: {
                Text("Variables")
            } footer: {
                Text("Only unused variables can be deleted.")
            }
        }
        .navigationTitle("Scenes")
    }
}
