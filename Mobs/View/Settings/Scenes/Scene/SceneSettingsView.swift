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
        model.database.widgets
    }

    var buttons: [SettingsButton] {
        model.database.buttons
    }

    func submitName(name: String) {
        scene.name = name
        model.store()
    }

    func drawWidgets(context: GraphicsContext) {
        for widget in scene.widgets.filter({ widget in widget.enabled }) {
            drawWidget(model: model, context: context, widget: widget)
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
                            if isImage(id: realWidget.id) {
                                NavigationLink(destination: SceneWidgetSettingsView(
                                    model: model,
                                    widget: widget
                                )) {
                                    Toggle(isOn: Binding(get: {
                                        widget.enabled
                                    }, set: { value in
                                        widget.enabled = value
                                        model.sceneUpdated()
                                    })) {
                                        HStack {
                                            Circle()
                                                .frame(width: 15, height: 15)
                                                .foregroundColor(colorOf(
                                                    model: model,
                                                    widget: widget
                                                ))
                                            Image(
                                                systemName: widgetImage(
                                                    widget: realWidget
                                                )
                                            )
                                            Text(realWidget.name)
                                        }
                                    }
                                }
                            } else {
                                Toggle(isOn: Binding(get: {
                                    widget.enabled
                                }, set: { value in
                                    widget.enabled = value
                                    model.sceneUpdated()
                                })) {
                                    HStack {
                                        Circle()
                                            .frame(width: 15, height: 15)
                                            .foregroundColor(colorOf(
                                                model: model,
                                                widget: widget
                                            ))
                                        Image(systemName: widgetImage(widget: realWidget))
                                        Text(realWidget.name)
                                    }
                                }
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
