import SwiftUI

var widgetColors: [Color] = [.red, .blue, .green, .brown, .mint, .pink]

struct SceneSettingsView: View {
    @ObservedObject var model: Model
    @State private var showingAddWidget = false
    @State private var showingAddButton = false
    @State private var selectedWidget = 0
    @State private var selectedButton = 0
    @State private var expandedWidget: SettingsSceneWidget?
    private var scene: SettingsScene

    init(scene: SettingsScene, model: Model) {
        self.scene = scene
        self.model = model
    }

    var widgets: [SettingsWidget] {
        model.database.widgets
    }

    var buttons: [SettingsButton] {
        model.database.buttons
    }

    func submitName(name: String) {
        scene.name = name
        model.store()
    }

    func colorOf(widget: SettingsSceneWidget) -> Color {
        guard let index = model.database.widgets
            .firstIndex(where: { item in item.id == widget.widgetId })
        else {
            return .blue
        }
        return widgetColors[index % widgetColors.count]
    }

    func drawWidgets(context: GraphicsContext) {
        for widget in scene.widgets.filter({ widget in widget.enabled }) {
            let stroke = 4.0
            let xScale = (1920.0 / 6 - stroke) / 100
            let yScale = (1080.0 / 6 - stroke) / 100
            let x = CGFloat(widget.x) * xScale + stroke / 2
            let y = CGFloat(widget.y) * yScale + stroke / 2
            let width = CGFloat(widget.width) * xScale
            let height = CGFloat(widget.height) * yScale
            let origin = CGPoint(x: x, y: y)
            let size = CGSize(width: width, height: height)
            context.stroke(
                Path(roundedRect: CGRect(origin: origin, size: size), cornerRadius: 2.0),
                with: .color(colorOf(widget: widget)),
                lineWidth: stroke
            )
        }
    }

    func buttonIndex(button: SettingsButton) -> Int {
        return buttons.firstIndex(of: button)!
    }

    func isImage(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widget.type == .image
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: scene.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: scene.name)
            }
            Section {
                HStack {
                    Spacer()
                    Canvas { context, _ in
                        drawWidgets(context: context)
                    }
                    .frame(width: 1920 / 6, height: 1080 / 6)
                    .border(.secondary)
                    Spacer()
                }
            } header: {
                Text("Preview")
            }
            Section {
                List {
                    ForEach(scene.widgets) { widget in
                        if let realWidget = widgets
                            .first(where: { item in item.id == widget.widgetId })
                        {
                            Button(action: {
                                if expandedWidget !== widget {
                                    expandedWidget = widget
                                } else {
                                    expandedWidget = nil
                                }
                            }, label: {
                                Toggle(isOn: Binding(get: {
                                    widget.enabled
                                }, set: { value in
                                    widget.enabled = value
                                    model.sceneUpdated()
                                })) {
                                    HStack {
                                        Circle()
                                            .frame(width: 15, height: 15)
                                            .foregroundColor(colorOf(widget: widget))
                                        Image(
                                            systemName: widgetImage(
                                                widget: realWidget
                                            )
                                        )
                                        Text(realWidget.name)
                                    }
                                }
                            })
                            .foregroundColor(.primary)
                            if expandedWidget === widget && isImage(id: realWidget.id) {
                                SceneWidgetSettingsView(model: model, widget: widget)
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        scene.widgets.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                    })
                    .onDelete(perform: { offsets in
                        scene.widgets.remove(atOffsets: offsets)
                        model.sceneUpdated()
                    })
                }
                AddButtonView(action: {
                    showingAddWidget = true
                })
                .popover(isPresented: $showingAddWidget) {
                    VStack {
                        Form {
                            Section("Widget name") {
                                Picker("", selection: $selectedWidget) {
                                    ForEach(widgets) { widget in
                                        IconAndTextView(
                                            image: widgetImage(widget: widget),
                                            text: widget.name
                                        )
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
                                scene.widgets
                                    .append(
                                        SettingsSceneWidget(widgetId: widgets[
                                            selectedWidget
                                        ]
                                        .id)
                                    )
                                model.sceneUpdated(imageEffectChanged: true)
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
                Text(
                    """
                    Widgets are stacked from back to front. There must be exactly \
                    one camera widget. The camera widget must be in the back.
                    """
                )
            }
            Section {
                List {
                    ForEach(scene.buttons) { button in
                        if let realButton = model.findButton(id: button.buttonId) {
                            Toggle(isOn: Binding(get: {
                                button.enabled
                            }, set: { value in
                                button.enabled = value
                                model.sceneUpdated()
                            })) {
                                IconAndTextView(
                                    image: realButton.systemImageNameOff,
                                    text: realButton.name
                                )
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        scene.buttons.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                    })
                    .onDelete(perform: { offsets in
                        scene.buttons.remove(atOffsets: offsets)
                        model.sceneUpdated()
                    })
                }
                AddButtonView(action: {
                    showingAddButton = true
                })
                .popover(isPresented: $showingAddButton) {
                    VStack {
                        Form {
                            Section("Button name") {
                                Picker("", selection: $selectedButton) {
                                    ForEach(buttons) { button in
                                        IconAndTextView(
                                            image: button.systemImageNameOff,
                                            text: button.name
                                        )
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
                                scene.addButton(id: buttons[selectedButton].id)
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
