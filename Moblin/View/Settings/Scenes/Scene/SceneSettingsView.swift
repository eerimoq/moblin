import SwiftUI

private struct VideoStabilizationView: View {
    let model: Model
    @ObservedObject var scene: SettingsScene

    var body: some View {
        HStack {
            Text("Video stabilization")
            Spacer()
            Picker("", selection: $scene.videoStabilizationMode) {
                ForEach(videoStabilizationModes, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            .onChange(of: scene.videoStabilizationMode) { _ in
                model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
            }
        }
    }
}

private struct MicView: View {
    let model: Model
    @ObservedObject var scene: SettingsScene
    @ObservedObject var mic: Mic

    private func onMicChange(micId: String) {
        scene.micId = micId
        if model.getSelectedScene() === scene {
            model.switchMicIfNeededAfterSceneSwitch()
        }
    }

    var body: some View {
        NavigationLink {
            InlinePickerView(
                title: String(localized: "Mic"),
                onChange: onMicChange,
                items: model.database.mics.mics.map {
                    InlinePickerItem(id: $0.id, text: $0.name)
                },
                selectedId: scene.micId
            )
        } label: {
            HStack {
                Text("Mic")
                Spacer()
                Text(model.getMicById(id: scene.micId)?.name ?? "Unknown 😢")
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .onAppear {
            if scene.micId.isEmpty {
                scene.micId = mic.current.id
            }
        }
    }
}

private struct SceneWidgetView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    let sceneWidget: SettingsSceneWidget

    var body: some View {
        if let widget = database.widgets.first(where: { item in item.id == sceneWidget.widgetId }) {
            NavigationLink {
                SceneWidgetSettingsView(
                    sceneWidget: sceneWidget,
                    widget: widget,
                    numericInput: $database.sceneNumericInput
                )
            } label: {
                Toggle(isOn: Binding(get: {
                    widget.enabled
                }, set: { value in
                    widget.enabled = value
                    model.sceneUpdated(attachCamera: model.isCaptureDeviceWidget(widget: widget))
                })) {
                    HStack {
                        DraggableItemPrefixView()
                        HStack {
                            Text("")
                            Image(systemName: widgetImage(widget: widget))
                            Text(widget.name)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}

struct SceneSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene
    @State private var showingAddWidget = false

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
        case .vTuber:
            sceneWidget.x = 80
            sceneWidget.y = 60
            sceneWidget.width = 28
            sceneWidget.height = 28
        case .pngTuber:
            sceneWidget.x = 85
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
            NameEditView(name: $scene.name, existingNames: database.scenes)
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
                    Label {
                        HStack {
                            Text("Name")
                            Spacer()
                            if !model.isSceneVideoSourceActive(scene: scene) {
                                Image(systemName: "cable.connector.slash")
                            }
                            Text(model.getCameraPositionName(scene: scene))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: "camera")
                    }
                }
                if scene.cameraPosition != .none {
                    VideoSourceRotationView(selectedRotation: $scene.videoSourceRotation)
                        .onChange(of: scene.videoSourceRotation) { _ in
                            model.sceneUpdated(updateRemoteScene: false)
                        }
                }
                Toggle("Override video stabilization", isOn: $scene.overrideVideoStabilizationMode)
                    .onChange(of: scene.overrideVideoStabilizationMode) { _ in
                        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                    }
                if scene.overrideVideoStabilizationMode {
                    VideoStabilizationView(model: model, scene: scene)
                }
                if scene.cameraPosition != .none {
                    Toggle("Fill frame", isOn: $scene.fillFrame)
                        .onChange(of: scene.fillFrame) { _ in
                            model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                        }
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
                Toggle("Override", isOn: $scene.overrideMic)
                    .onChange(of: scene.overrideMic) { _ in
                        model.switchMicIfNeededAfterSceneSwitch()
                    }
                if scene.overrideMic {
                    MicView(model: model, scene: scene, mic: model.mic)
                }
            } header: {
                Text("Mic")
            } footer: {
                Text("""
                Enable Override to automatically switch to selected mic (if available) when \
                switching to this scene.
                """)
            }
            Section {
                List {
                    ForEach(scene.widgets) { sceneWidget in
                        SceneWidgetView(database: database, sceneWidget: sceneWidget)
                    }
                    .onMove { froms, to in
                        scene.widgets.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                    }
                    .onDelete { offsets in
                        var attachCamera = false
                        if scene.id == model.getSelectedScene()?.id {
                            for offset in offsets {
                                if let widget = model.findWidget(id: scene.widgets[offset].widgetId) {
                                    attachCamera = model.isCaptureDeviceWidget(widget: widget)
                                }
                            }
                        }
                        scene.widgets.remove(atOffsets: offsets)
                        model.sceneUpdated(attachCamera: attachCamera)
                    }
                }
                AddButtonView(action: {
                    showingAddWidget = true
                })
                .popover(isPresented: $showingAddWidget) {
                    VStack {
                        if isPhone() {
                            HStack {
                                Spacer()
                                Button {
                                    showingAddWidget = false
                                } label: {
                                    Text("Cancel")
                                        .padding(5)
                                        .foregroundColor(.blue)
                                }
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
                                        Button {
                                            scene.widgets.append(createSceneWidget(widget: widget))
                                            var attachCamera = false
                                            if scene.id == model.getSelectedScene()?.id {
                                                attachCamera = model.isCaptureDeviceWidget(widget: widget)
                                            }
                                            model.sceneUpdated(imageEffectChanged: true, attachCamera: attachCamera)
                                            showingAddWidget = false
                                        } label: {
                                            IconAndTextView(
                                                image: widgetImage(widget: widget),
                                                text: widget.name,
                                                longDivider: true
                                            )
                                        }
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
