import SwiftUI

struct SceneSettingsView: View {
    var index: Int
    @ObservedObject var model: Model
    @State private var showingAdd = false
    @State private var selected = 0
    @State private var widgets: [Int]
    
    init(index: Int, model: Model) {
        self.index = index
        self.model = model
        self.widgets = Array(0..<model.database.scenes[index].widgets.count)
    }

    var scene: SettingsScene {
        get {
            model.settings.database.scenes[index]
        }
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: SceneNameSettingsView(model: model, scene: scene)) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(scene.name).foregroundColor(.gray)
                }
            }
            Section("Widgets") {
                List {
                    ForEach($widgets, id: \.self) { $widget in
                        let widget = scene.widgets[widget]
                        if let realWidget = model.database.widgets.first(where: {item in item.id == widget.id}) {
                            NavigationLink(destination: SceneWidgetSettingsView(model: model, widget: widget, name: realWidget.name)) {
                                Text(realWidget.name)
                            }
                        } else {
                            Text("Unknown")
                        }
                    }
                    .onMove() { (froms, to ) in
                        for from in froms {
                            let temp = scene.widgets[to]
                            scene.widgets[to] = scene.widgets[from]
                            scene.widgets[from] = temp
                        }
                        model.store()
                    }
                    .onDelete(perform: { offsets in
                        scene.widgets.remove(atOffsets: offsets)
                        widgets = Array(0..<scene.widgets.count)
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
                                    ForEach(0..<model.database.widgets.count, id: \.self) { tag in
                                        Text(model.database.widgets[tag].name).tag(tag)
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
                                let realWidget = model.database.widgets[selected]
                                scene.widgets.append(SettingsSceneWidget(id: realWidget.id))
                                widgets = Array(0..<scene.widgets.count)
                                model.store()
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

struct SceneSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SceneSettingsView(index: 0, model: Model())
    }
}
