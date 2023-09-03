import SwiftUI

struct SceneSettingsView: View {
    @ObservedObject var model: Model
    @State private var showingAdd = false
    @State private var selected = 0
    private var scene: SettingsScene
    
    init(scene: SettingsScene, model: Model) {
        self.scene = scene
        self.model = model
    }
    
    var widgets: [SettingsWidget] {
        get {
            model.database.widgets
        }
    }
    
    func submitName(name: String) {
        scene.name = name
        model.store()
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(name: scene.name, onSubmit: submitName)) {
                TextItemView(name: "Name", value: scene.name)
            }
            Section("Widgets") {
                List {
                    ForEach(scene.widgets) { widget in
                        if let realWidget = widgets.first(where: {item in item.id == widget.id}) {
                            NavigationLink(destination: SceneWidgetSettingsView(model: model, widget: widget, name: realWidget.name)) {
                                Text(realWidget.name)
                            }
                        }
                    }
                    .onMove(perform: { (froms, to) in
                        scene.widgets.move(fromOffsets: froms, toOffset: to)
                        model.store()
                    })
                    .onDelete(perform: { offsets in
                        scene.widgets.remove(atOffsets: offsets)
                        model.store()
                    })
                }
                AddButtonView(action: {
                    showingAdd = true
                })
                .popover(isPresented: $showingAdd) {
                    VStack {
                        Form {
                            Section("Name") {
                                Picker("", selection: $selected) {
                                    ForEach(widgets) { widget in
                                        Text(widget.name)
                                    }
                                }
                                .pickerStyle(.inline)
                                .labelsHidden()
                            }
                        }
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAdd = false
                            }, label: {
                                Text("Cancel")
                            })
                            Spacer()
                            Button(action: {
                                let realWidget = widgets[selected]
                                scene.widgets.append(SettingsSceneWidget(id: realWidget.id))
                                model.store()
                                model.objectWillChange.send()
                                showingAdd = false
                            }, label: {
                                Text("Done")
                            })
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Scene")
    }
}
