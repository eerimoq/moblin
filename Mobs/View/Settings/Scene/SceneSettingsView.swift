import SwiftUI

struct SceneSettingsView: View {
    var index: Int
    @ObservedObject var model: Model
    @State private var showingAdd = false
    @State private var selected = 0
    @State private var sceneWidgets: [Int]
    
    init(index: Int, model: Model) {
        self.index = index
        self.model = model
        self.sceneWidgets = Array(0..<model.database.scenes[index].widgets.count)
    }

    var scene: SettingsScene {
        get {
            model.database.scenes[index]
        }
    }
    
    var widgets: [SettingsWidget] {
        get {
            model.database.widgets
        }
    }
    
    func resetWidgets() {
        sceneWidgets = Array(0..<scene.widgets.count)
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: SceneNameSettingsView(model: model, scene: scene)) {
                TextItemView(name: "Name", value: scene.name)
            }
            Section("Widgets") {
                List {
                    ForEach($sceneWidgets, id: \.self) { $index in
                        let widget = scene.widgets[index]
                        if let realWidget = widgets.first(where: {item in item.id == widget.id}) {
                            NavigationLink(destination: SceneWidgetSettingsView(model: model, widget: widget, name: realWidget.name)) {
                                Text(realWidget.name)
                            }
                        }
                    }
                    .onMove(perform: { (froms, to) in
                        scene.widgets.move(fromOffsets: froms, toOffset: to)
                        model.store()
                        resetWidgets()
                    })
                    .onDelete(perform: { offsets in
                        scene.widgets.remove(atOffsets: offsets)
                        model.store()
                        resetWidgets()
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
                                    ForEach(0..<widgets.count, id: \.self) { tag in
                                        Text(widgets[tag].name)
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
                                resetWidgets()
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
