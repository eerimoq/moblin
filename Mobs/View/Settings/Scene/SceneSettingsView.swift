import SwiftUI

var widgetColors: [Color] = [.red, .blue, .green, .brown, .mint, .pink]

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
    
    func colorOf(widget: SettingsSceneWidget) -> Color {
        guard let index = model.database.widgets.firstIndex(where: {item in item.id == widget.widgetId}) else {
            return .blue
        }
        return widgetColors[index % widgetColors.count]
    }
    
    func drawWidgets(context: GraphicsContext, canvasSize: CGSize) {
        let stroke = 4.0
        let xScale = (1920.0 / 6 - stroke) / 100
        let yScale = (1080.0 / 6 - stroke) / 100
        for widget in scene.widgets {
            let x = CGFloat(widget.x) * xScale + stroke / 2
            let y = CGFloat(widget.y) * yScale + stroke / 2
            let w = CGFloat(widget.w) * xScale
            let h = CGFloat(widget.h) * yScale
            let origin = CGPoint(x: x, y: y)
            let size = CGSize(width: w, height: h)
            context.stroke(
                Path(roundedRect: CGRect(origin: origin, size: size), cornerRadius: 2.0),
                with: .color(colorOf(widget: widget)),
                lineWidth: stroke)
        }
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
                        drawWidgets(context: context, canvasSize: size)
                    }
                    .frame(width: 1920 / 6, height: 1080 / 6)
                    .border(.black)
                    Spacer()
                }

            }
            Section("Widgets") {
                List {
                    ForEach(scene.widgets) { widget in
                        if let realWidget = widgets.first(where: {item in item.id == widget.widgetId}) {
                            NavigationLink(destination: SceneWidgetSettingsView(model: model, widget: widget, name: realWidget.name)) {
                                HStack {
                                    Circle()
                                        .frame(width: 15, height: 15)
                                        .foregroundColor(colorOf(widget: widget))
                                    Text(realWidget.name)
                                    Spacer()
                                    Text("(\(widget.x), \(widget.y))").foregroundColor(.gray)
                                }
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
