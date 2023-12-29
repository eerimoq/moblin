import SwiftUI

struct SceneSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var showingAddWidget = false
    @State private var showingAddButton = false
    @State private var expandedWidget: SettingsSceneWidget?
    var scene: SettingsScene
    @State var showPipSmallCameraDimensions = false

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

    private func widgetHasPosition(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widget.type == .image || widget.type == .browser || widget
                .type == .time
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private func widgetHasSize(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widget.type == .image || widget.type == .browser
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private func createSceneWidget(widget: SettingsWidget) -> SettingsSceneWidget {
        let sceneWidget = SettingsSceneWidget(widgetId: widget.id)
        switch widget.type {
        case .time:
            sceneWidget.x = 91
            sceneWidget.y = 1
            sceneWidget.width = 8
            sceneWidget.height = 5
        case .image:
            sceneWidget.width = 30
            sceneWidget.height = 40
        case .browser:
            sceneWidget.width = 30
            sceneWidget.height = 40
        default:
            break
        }
        return sceneWidget
    }

    private func pipSmall() -> String {
        switch scene.cameraPosition! {
        case .back:
            return SettingsSceneCameraPosition.front.toString()
        case .front:
            return SettingsSceneCameraPosition.back.toString()
        case .rtmp:
            return SettingsSceneCameraPosition.rtmp.toString()
        }
    }

    private func onLayoutChange(layout: String) {
        scene.cameraLayout = SettingsSceneCameraLayout.fromString(value: layout)
        model.sceneUpdated(store: true)
    }

    private func onCameraChange(camera: String) {
        if isRtmpCamera(camera: camera) {
            scene.cameraPosition = .rtmp
            scene.rtmpCameraId = model.getRtmpStream(camera: camera)?.id ?? .init()
        } else {
            scene.cameraPosition = SettingsSceneCameraPosition.fromString(value: camera)
        }
        model.sceneUpdated(store: true)
    }

    private func canWidgetExpand(widget: SettingsWidget) -> Bool {
        return widgetHasPosition(id: widget.id) || widgetHasSize(id: widget.id)
    }

    private func getCameraPosition() -> String {
        if scene.cameraPosition! == .rtmp {
            if let stream = model.getRtmpStream(id: scene.rtmpCameraId!) {
                return stream.camera()
            } else {
                return "Back"
            }
        } else {
            return scene.cameraPosition!.toString()
        }
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: scene.name,
                onSubmit: submitName
            )) {
                TextItemView(name: String(localized: "Name"), value: scene.name)
            }
            Section {
                NavigationLink(destination: InlinePickerView(
                    title: String(localized: "Layout"),
                    onChange: onLayoutChange,
                    footers: [
                        String(localized: "The Picture in Picture layout is experimental and does not work."),
                    ],
                    items: InlinePickerItem.fromStrings(values: cameraLayouts),
                    selectedId: scene.cameraLayout!.toString()
                )) {
                    TextItemView(name: String(localized: "Layout"), value: scene.cameraLayout!.toString())
                }
                if scene.cameraLayout == .single {
                    NavigationLink(destination: InlinePickerView(
                        title: String(localized: "Camera"),
                        onChange: onCameraChange,
                        items: InlinePickerItem.fromStrings(values: model.listCameraPositions()),
                        selectedId: getCameraPosition()
                    )) {
                        TextItemView(
                            name: String(localized: "Camera"),
                            value: getCameraPosition()
                        )
                    }
                } else if scene.cameraLayout == .pip {
                    NavigationLink(destination: InlinePickerView(
                        title: String(localized: "Large camera"),
                        onChange: onCameraChange,
                        items: InlinePickerItem.fromStrings(values: model.listCameraPositions()),
                        selectedId: getCameraPosition()
                    )) {
                        TextItemView(
                            name: String(localized: "Large camera"),
                            value: getCameraPosition()
                        )
                    }
                    Button(action: {
                        showPipSmallCameraDimensions.toggle()
                    }, label: {
                        TextItemView(name: String(localized: "Small camera"), value: pipSmall())
                    })
                    .foregroundColor(.primary)
                    if showPipSmallCameraDimensions {
                        SceneCameraPipSmallCameraSettingsView(scene: scene)
                    }
                }
            } header: {
                Text("Camera")
            }
            Section {
                List {
                    ForEach(scene.widgets) { widget in
                        if let realWidget = widgets
                            .first(where: { item in item.id == widget.widgetId })
                        {
                            let expanded = expandedWidget === widget && canWidgetExpand(widget: realWidget)
                            Button(action: {
                                if expandedWidget !== widget {
                                    expandedWidget = widget
                                } else {
                                    expandedWidget = nil
                                }
                            }, label: {
                                HStack {
                                    DraggableItemPrefixView()
                                    Toggle(isOn: Binding(get: {
                                        widget.enabled
                                    }, set: { value in
                                        widget.enabled = value
                                        model.sceneUpdated()
                                    })) {
                                        HStack {
                                            Text("")
                                            Image(
                                                systemName: widgetImage(
                                                    widget: realWidget
                                                )
                                            )
                                            Text(realWidget.name)
                                        }
                                    }
                                    if canWidgetExpand(widget: realWidget) {
                                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                    }
                                }
                            })
                            .foregroundColor(.primary)
                            if expanded {
                                SceneWidgetSettingsView(
                                    hasPosition: widgetHasPosition(id: realWidget.id),
                                    hasSize: widgetHasSize(id: realWidget.id),
                                    widget: widget
                                )
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
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddWidget = false
                            }, label: {
                                Text("Cancel")
                                    .padding(5)
                                    .foregroundColor(.blue)
                            })
                        }
                        Form {
                            Section("Widget name") {
                                ForEach(widgets) { widget in
                                    Button(action: {
                                        scene.widgets
                                            .append(createSceneWidget(widget: widget))
                                        model.sceneUpdated(imageEffectChanged: true)
                                        showingAddWidget = false
                                    }, label: {
                                        IconAndTextView(
                                            image: widgetImage(widget: widget),
                                            text: widget.name
                                        )
                                    })
                                }
                            }
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
                            HStack {
                                DraggableItemPrefixView()
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
                        HStack {
                            Spacer()
                            Button(action: {
                                showingAddButton = false
                            }, label: {
                                Text("Cancel")
                                    .padding(5)
                                    .foregroundColor(.blue)
                            })
                        }
                        Form {
                            Section("Button name") {
                                ForEach(buttons) { button in
                                    Button(action: {
                                        scene.addButton(id: button.id)
                                        model.sceneUpdated()
                                        showingAddButton = false
                                    }, label: {
                                        IconAndTextView(
                                            image: button.systemImageNameOff,
                                            text: button.name
                                        )
                                    })
                                }
                            }
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
        .toolbar {
            SettingsToolbar()
        }
    }
}
