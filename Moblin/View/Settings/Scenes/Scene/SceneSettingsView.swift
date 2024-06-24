import SwiftUI

struct SceneSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var showingAddWidget = false
    @State private var expandedWidget: SettingsSceneWidget?
    var scene: SettingsScene

    var widgets: [SettingsWidget] {
        model.database.widgets
    }

    func submitName(name: String) {
        scene.name = name
        model.store()
    }

    private func widgetHasPosition(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widget.type == .image || widget.type == .browser || widget
                .type == .time || widget.type == .crop
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

    private func onCameraChange(cameraId: String) {
        if isSrtlaCamera(camera: cameraId) {
            scene.cameraPosition = .srtla
            scene.srtlaCameraId = model.getSrtlaStream(camera: cameraId)?.id ?? .init()
        } else if isRtmpCamera(camera: cameraId) {
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
                    title: String(localized: "Camera"),
                    onChange: onCameraChange,
                    footers: [
                        String(localized: """
                        The ultra wide camera does not perform well in low light conditions. Likewise, the \
                        auto cameras do not perform well when zoom is 0.5-1.0x since the ultra wide camera \
                        will be used.
                        """),
                        "",
                        String(localized: """
                        Auto cameras use more energy as multiple cameras are powered on, even if only \
                        one is used at a time. This allows the phone to quickly change camera when zooming.
                        """),
                    ],
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
                            if widgets.isEmpty {
                                Section {
                                    Text("No widgets found. Create widgets in Settings → Scenes → Widgets.")
                                }
                            } else {
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
                                                text: widget.name,
                                                longDivider: true
                                            )
                                        })
                                    }
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
                VStack(alignment: .leading) {
                    SwipeLeftToRemoveHelpView(kind: String(localized: "a widget"))
                    Text("")
                    Text("Widgets are stacked from back to front.")
                }
            }
        }
        .navigationTitle("Scene")
        .toolbar {
            SettingsToolbar()
        }
    }
}
