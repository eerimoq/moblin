import SwiftUI

private struct VideoStabilizationView: View {
    @EnvironmentObject var model: Model
    var scene: SettingsScene
    @State var mode: String

    var body: some View {
        HStack {
            Text("Video stabilization")
            Spacer()
            Picker("", selection: $mode) {
                ForEach(videoStabilizationModes, id: \.self) {
                    Text($0)
                }
            }
            .onChange(of: mode) {
                scene.videoStabilizationMode = SettingsVideoStabilizationMode.fromString(value: $0)
                model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
            }
        }
    }
}

struct SceneSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var showingAddWidget = false
    @State private var expandedWidget: SettingsSceneWidget?
    var scene: SettingsScene
    @State var name: String
    @State var selectedRotation: Double

    var widgets: [SettingsWidget] {
        model.database.widgets
    }

    private func createSceneWidget(widget: SettingsWidget) -> SettingsSceneWidget {
        let sceneWidget = SettingsSceneWidget(widgetId: widget.id)
        switch widget.type {
        case .text:
            sceneWidget.x = 0
            sceneWidget.y = 0
            sceneWidget.width = 8
            sceneWidget.height = 5
        case .image:
            sceneWidget.width = 30
            sceneWidget.height = 40
        case .map:
            sceneWidget.width = 13
            sceneWidget.height = 23
        case .videoSource:
            sceneWidget.x = 72
            sceneWidget.y = 72
            sceneWidget.width = 28
            sceneWidget.height = 28
        default:
            break
        }
        return sceneWidget
    }

    private func onCameraChange(cameraId: String) {
        scene.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    var body: some View {
        Form {
            NavigationLink {
                NameEditView(name: $name)
            } label: {
                TextItemView(name: String(localized: "Name"), value: name)
            }
            .onChange(of: name) { name in
                scene.name = name
            }
            Section {
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Name"),
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
                    )
                } label: {
                    HStack {
                        Text("Name")
                        Spacer()
                        if !model.isSceneActive(scene: scene) {
                            Image(systemName: "cable.connector.slash")
                        }
                        Text(model.getCameraPositionName(scene: scene))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                VideoSourceRotationView(selectedRotation: $selectedRotation)
                    .onChange(of: selectedRotation) { rotation in
                        scene.videoSourceRotation = rotation
                        model.sceneUpdated(updateRemoteScene: false)
                    }
                Toggle(isOn: Binding(get: {
                    scene.overrideVideoStabilizationMode!
                }, set: { value in
                    scene.overrideVideoStabilizationMode = value
                    model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                })) {
                    Text("Override video stabilization")
                }
                if scene.overrideVideoStabilizationMode! {
                    VideoStabilizationView(scene: scene, mode: scene.videoStabilizationMode!.toString())
                }
                Toggle(isOn: Binding(get: {
                    scene.fillFrame!
                }, set: { value in
                    scene.fillFrame = value
                    model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                })) {
                    Text("Fill frame")
                }
            } header: {
                Text("Video source")
            } footer: {
                Text("""
                Enable Override video stabilization to override Settings → Camera → Video \
                stabilization in this scene.
                """)
            }
            Section {
                List {
                    ForEach(scene.widgets) { sceneWidget in
                        if let widget = widgets.first(where: { item in item.id == sceneWidget.widgetId }) {
                            NavigationLink {
                                SceneWidgetSettingsView(
                                    sceneWidget: sceneWidget,
                                    widget: widget
                                )
                            } label: {
                                HStack {
                                    DraggableItemPrefixView()
                                    HStack {
                                        Text("")
                                        Image(systemName: widgetImage(widget: widget))
                                        Text(widget.name)
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
                        var attachCamera = false
                        if scene.id == model.getSelectedScene()?.id {
                            for offset in offsets {
                                if let widget = model.findWidget(id: scene.widgets[offset].widgetId) {
                                    attachCamera = model.isCaptureDeviceVideoSoureWidget(widget: widget)
                                }
                            }
                        }
                        scene.widgets.remove(atOffsets: offsets)
                        model.sceneUpdated(attachCamera: attachCamera)
                    })
                }
                AddButtonView(action: {
                    showingAddWidget = true
                })
                .popover(isPresented: $showingAddWidget) {
                    VStack {
                        if isPhone() {
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
                                            scene.widgets.append(createSceneWidget(widget: widget))
                                            var attachCamera = false
                                            if scene.id == model.getSelectedScene()?.id {
                                                attachCamera = model.isCaptureDeviceVideoSoureWidget(widget: widget)
                                            }
                                            model.sceneUpdated(
                                                imageEffectChanged: true,
                                                attachCamera: attachCamera
                                            )
                                            model.objectWillChange.send()
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
                        if !isPhone() {
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
                }
            }
        }
        .navigationTitle("Scene")
    }
}
