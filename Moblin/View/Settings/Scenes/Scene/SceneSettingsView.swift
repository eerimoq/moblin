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
            return widget.type == .image
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
        case .external:
            return SettingsSceneCameraPosition.external.toString()
        }
    }

    private func onLayoutChange(layout: String) {
        scene.cameraLayout = SettingsSceneCameraLayout.fromString(value: layout)
        model.sceneUpdated(store: true)
    }

    private func onCameraChange(cameraId: String) {
        if isRtmpCamera(camera: cameraId) {
            scene.cameraPosition = .rtmp
            scene.rtmpCameraId = model.getRtmpStream(camera: cameraId)?.id ?? .init()
        } else if model.isBackCamera(cameraId: cameraId) {
            scene.cameraPosition = .back
            scene.backCameraId = cameraId
        } else if model.isFrontCamera(cameraId: cameraId) {
            scene.cameraPosition = .front
            scene.frontCameraId = cameraId
        } else {
            scene.cameraPosition = .external
            scene.externalCameraId = cameraId
            scene.externalCameraName = model.getExternalCameraName(cameraId: cameraId)
        }
        model.sceneUpdated(store: true)
    }

    private func canWidgetExpand(widget: SettingsWidget) -> Bool {
        return widgetHasPosition(id: widget.id) || widgetHasSize(id: widget.id)
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
                        items: model.listCameraPositions().map { id, name in
                            InlinePickerItem(id: id, text: name)
                        },
                        selectedId: model.getCameraPositionId(scene: scene)
                    )) {
                        HStack {
                            Text(String(localized: "Camera"))
                            Spacer()
                            if !model.isSceneActive(scene: scene) {
                                Image(systemName: "cable.connector.slash")
                            }
                            Text(model.getCameraPositionName(scene: scene))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                } else if scene.cameraLayout == .pip {
                    NavigationLink(destination: InlinePickerView(
                        title: String(localized: "Large camera"),
                        onChange: onCameraChange,
                        items: model.listCameraPositions().map { id, name in
                            InlinePickerItem(id: id, text: name)
                        },
                        selectedId: model.getCameraPositionId(scene: scene)
                    )) {
                        TextItemView(
                            name: String(localized: "Large camera"),
                            value: model.getCameraPositionName(scene: scene)
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
                        if UIDevice.current.userInterfaceIdiom == .phone {
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
                        }
                        let form = Form {
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
                        if UIDevice.current.userInterfaceIdiom != .phone {
                            form
                                .frame(width: 300, height: 400)
                        } else {
                            form
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
                        if UIDevice.current.userInterfaceIdiom == .phone {
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
                        }
                        let form = Form {
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
                        if UIDevice.current.userInterfaceIdiom != .phone {
                            form
                                .frame(width: 300, height: 400)
                        } else {
                            form
                        }
                    }
                }
            } header: {
                Text("Quick buttons")
            } footer: {
                Text("Quick buttons appear from bottom to top.")
            }
        }
        .navigationTitle("Scene")
        .toolbar {
            SettingsToolbar()
        }
    }
}
