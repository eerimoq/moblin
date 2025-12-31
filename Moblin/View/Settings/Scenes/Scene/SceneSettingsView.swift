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
                title: "Mic",
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
                GrayTextView(text: model.getMicById(id: scene.micId)?.name ?? "Unknown 😢")
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

private struct VideoSourceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene
    @State private var presentingScreenCaptureAlert = false

    private func onCameraChange(cameraId: String) {
        scene.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
        if model.isScreenCaptureCamera(cameraId: cameraId) {
            presentingScreenCaptureAlert = true
        }
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: "Name",
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
                        GrayTextView(text: model.getCameraPositionName(scene: scene))
                    }
                } icon: {
                    Image(systemName: "camera")
                }
            }
            .alert(
                """
                Start a screen capture by long-pressing the record button in iOS Control Center and select Moblin.
                """,
                isPresented: $presentingScreenCaptureAlert
            ) {
                Button("Got it") {
                    presentingScreenCaptureAlert = false
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
    }
}

private struct QuickSwitchGroupView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene

    var body: some View {
        Section {
            Picker("Quick switch group", selection: $scene.quickSwitchGroup) {
                Text("-- None --")
                    .tag(nil as Int?)
                ForEach(1 ..< 5, id: \.self) { group in
                    Text(String(group))
                        .tag(group as Int?)
                }
            }
            .onChange(of: scene.quickSwitchGroup) { _ in
                if model.getSelectedScene() === scene {
                    model.resetSelectedScene(changeScene: false, attachCamera: true)
                }
            }
        } footer: {
            VStack(alignment: .leading) {
                Text("Switching between scenes in the same group may be instant.")
                if database.forceSceneSwitchTransition {
                    Text("")
                    Text("⚠️ Disable Settings → Scenes → Scene switching → Force transition to enable groups.")
                }
            }
        }
    }
}

private struct SceneMicView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene

    var body: some View {
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
    }
}

private struct WidgetsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene
    @State private var presentingAddWidget = false

    private var widgets: [SettingsWidget] {
        database.widgets
    }

    var body: some View {
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
            AddButtonView {
                presentingAddWidget = true
            }
            .disabled(widgets.isEmpty)
            .popover(isPresented: $presentingAddWidget) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(widgets) { widget in
                            Button {
                                model.appendWidgetToScene(scene: scene, widget: widget)
                                presentingAddWidget = false
                            } label: {
                                HStack {
                                    IconAndTextView(image: widget.image(), text: widget.name)
                                    Spacer()
                                }
                            }
                            .foregroundStyle(.primary)
                            .padding(11)
                        }
                    }
                }
                .frame(minWidth: 220)
                .padding(5)
                .presentationCompactAdaptation(.none)
            }
        } header: {
            Text("Widgets")
        } footer: {
            VStack(alignment: .leading) {
                SwipeLeftToRemoveHelpView(kind: String(localized: "a widget"))
            }
        }
    }
}

struct SceneShortcutView: View {
    let database: Database
    let scene: SettingsScene

    var body: some View {
        NavigationLink {
            SceneSettingsView(database: database, scene: scene)
        } label: {
            Text("Scene")
        }
    }
}

struct SceneSettingsView: View {
    let database: Database
    @ObservedObject var scene: SettingsScene

    var body: some View {
        Form {
            NameEditView(name: $scene.name, existingNames: database.scenes)
            VideoSourceView(database: database, scene: scene)
            QuickSwitchGroupView(database: database, scene: scene)
            SceneMicView(database: database, scene: scene)
            WidgetsView(database: database, scene: scene)
        }
        .navigationTitle("Scene")
    }
}
