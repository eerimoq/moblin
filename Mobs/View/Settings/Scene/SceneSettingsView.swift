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
            Section("Preview") {
                HStack {
                    Spacer()
                    Canvas { context, size in
                        let fullOrigin = CGPoint(x: 2, y: 2)
                        let fullSize = CGSize(width: size.width - 4, height: size.height - 4)
                        context.stroke(
                            Path(roundedRect: CGRect(origin: fullOrigin, size: fullSize), cornerRadius: 2.0),
                            with: .color(.red),
                            lineWidth: 2)
                        let smallOrigin = CGPoint(x: 2 * size.width / 3 - 2, y: 2)
                        let smallSize = CGSize(width: size.width / 3, height: size.height / 3)
                        context.stroke(
                            Path(roundedRect: CGRect(origin: smallOrigin, size: smallSize), cornerRadius: 2.0),
                            with: .color(.blue),
                            lineWidth: 2)
                    }
                    .frame(width: 1920/6, height: 1080/6)
                    .border(.black)
                    Spacer()
                }

            }
            Section("Widgets") {
                List {
                    ForEach(scene.widgets) { widget in
                        if let realWidget = widgets.first(where: {item in item.id == widget.widgetId}) {
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
                                        Text(widget.name).tag(widgets.firstIndex(of: widget)!)
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
                                scene.widgets.append(SettingsSceneWidget(widgetId: widgets[selected].id))
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
