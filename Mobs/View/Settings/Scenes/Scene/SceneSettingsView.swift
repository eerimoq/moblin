import SwiftUI

var widgetColors: [Color] = [.red, .blue, .green, .brown, .mint, .pink]

struct SceneSettingsView: View {
    @ObservedObject var model: Model
    @State private var showingAddWidget = false
    @State private var showingAddButton = false
    @State private var selectedWidget = 0
    @State private var selectedButton = 0
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
    
    var buttons: [SettingsButton] {
        get {
            model.database.buttons
        }
    }
    
    func submitName(name: String) {
        scene.name = name
        model.store()
    }
    
    func colorOf(widget: SettingsSceneWidget) -> Color {
        guard let index = model.database.widgets.firstIndex(where: {item in item.id == widget.widgetId}) else {
            return .blue
        }
        return widgetColors[index % widgetColors.count]
    }
    
    func drawWidgets(context: GraphicsContext) {
        let stroke = 4.0
        let xScale = (1920.0 / 6 - stroke) / 100
        let yScale = (1080.0 / 6 - stroke) / 100
        for widget in scene.widgets {
            let x = CGFloat(widget.x) * xScale + stroke / 2
            let y = CGFloat(widget.y) * yScale + stroke / 2
            let width = CGFloat(widget.width) * xScale
            let height = CGFloat(widget.height) * yScale
            let origin = CGPoint(x: x, y: y)
            let size = CGSize(width: width, height: height)
            context.stroke(
                Path(roundedRect: CGRect(origin: origin, size: size), cornerRadius: 2.0),
                with: .color(colorOf(widget: widget)),
                lineWidth: stroke)
        }
    }
    
    func buttonIndex(button: SettingsButton) -> Int {
        return buttons.firstIndex(of: button)!
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
                        drawWidgets(context: context)
                    }
                    .frame(width: 1920 / 6, height: 1080 / 6)
                    .border(.black)
                    Spacer()
                }
            }
            Section {
                List {
                    ForEach(scene.widgets) { widget in
                        if let realWidget = widgets.first(where: {item in item.id == widget.widgetId}) {
                            NavigationLink(destination: SceneWidgetSettingsView(model: model, widget: widget, name: realWidget.name)) {
                                Toggle(isOn: Binding(get: {
                                    widget.enabled
                                }, set: { value in
                                    widget.enabled = value
                                    model.store()
                                    model.sceneUpdated()
                                })) {
                                    HStack {
                                        Circle()
                                            .frame(width: 15, height: 15)
                                            .foregroundColor(colorOf(widget: widget))
                                        Image(systemName: widgetImage(widget: realWidget))
                                        Text(realWidget.name)
                                    }
                                }
                            }
                        }
                    }
                    .onMove(perform: { (froms, to) in
                        scene.widgets.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                        model.store()
                    })
                    .onDelete(perform: { offsets in
                        scene.widgets.remove(atOffsets: offsets)
                        model.sceneUpdated()
                        model.store()
                    })
                }
                AddButtonView(action: {
                    showingAddWidget = true
                })
                .popover(isPresented: $showingAddWidget) {
                    VStack {
                        Form {
                            Section("Name") {
                                Picker("", selection: $selectedWidget) {
                                    ForEach(widgets) { widget in
                                        HStack {
                                            Image(systemName: widgetImage(widget: widget))
                                            Text(widget.name)
                                        }
                                        .tag(widgets.firstIndex(of: widget)!)
                                    }
                                }
                                .pickerStyle(.inline)
                                .labelsHidden()
                            }
                        }
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddWidget = false
                            }, label: {
                                Text("Cancel")
                            })
                            Spacer()
                            Button(action: {
                                scene.widgets.append(SettingsSceneWidget(widgetId: widgets[selectedWidget].id))
                                model.store()
                                model.sceneUpdated()
                                showingAddWidget = false
                            }, label: {
                                Text("Done")
                            })
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Widgets")
            } footer: {
                Text("Widgets are stacked from back to front.")
            }
            Section {
                List {
                    ForEach(scene.buttons) { button in
                        if let realButton = model.findButton(id: button.buttonId) {
                            Toggle(isOn: Binding(get: {
                                button.enabled
                            }, set: { value in
                                button.enabled = value
                                model.store()
                                model.sceneUpdated()
                            })) {
                                HStack {
                                    Image(systemName: realButton.systemImageNameOff)
                                    Text(realButton.name)
                                }
                            }
                        }
                    }
                    .onMove(perform: { (froms, to) in
                        scene.buttons.move(fromOffsets: froms, toOffset: to)
                        model.store()
                        model.sceneUpdated()
                    })
                    .onDelete(perform: { offsets in
                        scene.buttons.remove(atOffsets: offsets)
                        model.store()
                        model.sceneUpdated()
                    })
                }
                AddButtonView(action: {
                    showingAddButton = true
                })
                .popover(isPresented: $showingAddButton) {
                    VStack {
                        Form {
                            Section("Name") {
                                Picker("", selection: $selectedButton) {
                                    ForEach(buttons) { button in
                                        HStack {
                                            Image(systemName: button.systemImageNameOff)
                                            Text(button.name)
                                        }
                                        .tag(buttonIndex(button: button))
                                    }
                                }
                                .pickerStyle(.inline)
                                .labelsHidden()
                            }
                        }
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddButton = false
                            }, label: {
                                Text("Cancel")
                            })
                            Spacer()
                            Button(action: {
                                scene.buttons.append(SettingsSceneButton(buttonId: buttons[selectedButton].id))
                                model.store()
                                model.sceneUpdated()
                                showingAddButton = false
                            }, label: {
                                Text("Done")
                            })
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Buttons")
            } footer: {
                Text("Buttons appear from bottom to top.")
            }
        }
        .navigationTitle("Scene")
    }
}
