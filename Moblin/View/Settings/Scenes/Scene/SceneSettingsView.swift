import SwiftUI

private struct VideoStabilizationView: View {
    let model: Model
    @ObservedObject var scene: SettingsScene

    var body: some View {
        Picker("Video stabilization", selection: $scene.videoStabilizationMode) {
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
                    .foregroundStyle(.gray)
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
        if let widget = database.widgets.first(where: { $0.id == sceneWidget.widgetId }) {
            NavigationLink {
                SceneWidgetSettingsView(
                    model: model,
                    database: database,
                    sceneWidget: sceneWidget,
                    widget: widget
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
                            Image(systemName: widget.image())
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
    @State private var showingScreenCaptureAlert = false

    var widgets: [SettingsWidget] {
        model.database.widgets
    }

    private func onCameraChange(cameraId: String) {
        scene.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
        if model.isScreenCaptureCamera(cameraId: cameraId) {
            showingScreenCaptureAlert = true
        }
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
                                .foregroundStyle(.gray)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: "camera")
                    }
                }
                .alert(
                    """
                    Start a screen capture by long-pressing the record button in iOS Control Center and select Moblin.
                    """,
                    isPresented: $showingScreenCaptureAlert
                ) {
                    Button("Got it") {
                        showingScreenCaptureAlert = false
                    }
                }
                if database.showAllSettings {
                    if scene.videoSource.cameraPosition != .none {
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
                    if scene.videoSource.cameraPosition != .none {
                        Toggle("Fill frame", isOn: $scene.fillFrame)
                            .onChange(of: scene.fillFrame) { _ in
                                model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                            }
                    }
                }
            } header: {
                Text("Video source")
            } footer: {
                if database.showAllSettings {
                    Text("""
                    Enable Override video stabilization to override Settings → Camera → Video \
                    stabilization in this scene.
                    """)
                }
            }
            if database.showAllSettings {
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
                                        .foregroundStyle(.blue)
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
                                            model.appendWidgetToScene(scene: scene, widget: widget)
                                            showingAddWidget = false
                                        } label: {
                                            IconAndTextView(
                                                image: widget.image(),
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
