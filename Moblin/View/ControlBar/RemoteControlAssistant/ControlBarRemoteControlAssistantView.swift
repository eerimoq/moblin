import Collections
import SwiftUI

private struct StatusItemView: View {
    let icon: String
    let status: RemoteControlStatusItem?

    var body: some View {
        if let status {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(status.ok ? .primary : Color.red)
                    .frame(width: 20)
                Text(status.message)
            }
            .font(smallFont)
        }
    }
}

private struct RemoteControlSrtConnectionPriorityView: View {
    let model: Model
    let priority: RemoteControlSettingsSrtConnectionPriority
    @State var enabled: Bool
    @State var prio: Float

    private func makeName() -> String {
        if let name = model.database.networkInterfaceNames.first(where: { interface in
            interface.interfaceName == priority.name
        })?.name, !name.isEmpty {
            return name
        } else {
            return priority.name
        }
    }

    var body: some View {
        VStack {
            Toggle(isOn: Binding(get: {
                enabled
            }, set: {
                var priority = priority
                priority.enabled = $0
                enabled = $0
                model.remoteControlAssistantSetSrtConnectionPriority(priority: priority)
            })) {
                Text(makeName())
            }
            Slider(
                value: $prio,
                in: Float(minimumSrtConnectionPriority) ... Float(maximumSrtConnectionPriority),
                step: 1,
                label: {
                    EmptyView()
                },
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    var priority = priority
                    priority.priority = clampConnectionPriority(value: Int(prio))
                    model.remoteControlAssistantSetSrtConnectionPriority(priority: priority)
                }
            )
        }
    }
}

private struct RemoteControlSrtConnectionPrioritiesView: View {
    let model: Model
    var srt: RemoteControlSettingsSrt
    @State var enabled: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    enabled
                }, set: {
                    enabled = $0
                    model.remoteControlAssistantSetSrtConnectionPriorityEnabled(enabled: $0)
                }))
            }
            Section {
                ForEach(srt.connectionPriorities) { priority in
                    RemoteControlSrtConnectionPriorityView(
                        model: model,
                        priority: priority,
                        enabled: priority.enabled,
                        prio: Float(priority.priority)
                    )
                }
            }
        }
        .navigationTitle("SRT connection priorities")
    }
}

private struct RemoteControlAudioLevelView: View {
    var level: Float
    var channels: Int?
    private let barsPerDb: Float = 0.3
    private let clippingThresholdDb: Float = -1.0
    private let redThresholdDb: Float = -8.5
    private let yellowThresholdDb: Float = -20
    private let zeroThresholdDb: Float = -60

    // Approx 60 * 0.3 = 20
    private let maxBars = "||||||||||||||||||||"

    private func bars(count: Float) -> Substring {
        let barCount = Int(count.rounded(.toNearestOrAwayFromZero))
        return maxBars.prefix(barCount)
    }

    private func isClipping() -> Bool {
        return level > clippingThresholdDb
    }

    private func clippingText() -> Substring {
        let db = -zeroThresholdDb
        return bars(count: db * barsPerDb)
    }

    private func redText() -> Substring {
        guard level > redThresholdDb else {
            return ""
        }
        let db = level - redThresholdDb
        return bars(count: db * barsPerDb)
    }

    private func yellowText() -> Substring {
        guard level > yellowThresholdDb else {
            return ""
        }
        let db = min(level - yellowThresholdDb, redThresholdDb - yellowThresholdDb)
        return bars(count: db * barsPerDb)
    }

    private func greenText() -> Substring {
        guard level > zeroThresholdDb else {
            return ""
        }
        let db = min(level - zeroThresholdDb, yellowThresholdDb - zeroThresholdDb)
        return bars(count: db * barsPerDb)
    }

    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .frame(width: 20)
            HStack(spacing: 1) {
                if level.isNaN {
                    if channels == nil {
                        Text("Muted")
                    } else {
                        Text("Muted,")
                    }
                } else if level == .infinity {
                    if channels == nil {
                        Text("Unknown")
                    } else {
                        Text("Unknown,")
                    }
                } else {
                    HStack(spacing: 0) {
                        if isClipping() {
                            Text(clippingText())
                                .foregroundStyle(.red)
                        } else {
                            Text(redText())
                                .foregroundStyle(.red)
                            Text(yellowText())
                                .foregroundStyle(.yellow)
                            Text(greenText())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.bottom, 3)
                    .bold()
                }
                if let channels {
                    Text(formatAudioLevelChannels(channels: channels))
                }
            }
            .font(smallFont)
        }
    }
}

private struct ControlBarRemoteControlAssistantStatusView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl
    var title: LocalizedStringKey = ""

    private func batteryStatus(status: RemoteControlStatusGeneral) -> RemoteControlStatusItem? {
        guard let charging = status.batteryCharging, let level = status.batteryLevel else {
            return nil
        }
        var message = "\(level)%"
        if charging {
            message += ", Charging"
        } else {
            message += ", Not charging"
        }
        return RemoteControlStatusItem(message: message)
    }

    private func flameStatus(status: RemoteControlStatusGeneral) -> RemoteControlStatusItem? {
        guard let flame = status.flame else {
            return nil
        }
        return RemoteControlStatusItem(message: flame.rawValue)
    }

    private func ssidStatus(status: RemoteControlStatusGeneral) -> RemoteControlStatusItem? {
        guard let wiFiSsid = status.wiFiSsid else {
            return nil
        }
        return RemoteControlStatusItem(message: wiFiSsid)
    }

    var body: some View {
        Section {
            if remoteControl.presentingPreview {
                if let preview = remoteControl.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 3)
                        .onTapGesture(count: 2) { _ in
                            remoteControl.presentingPreviewFullScreen = true
                        }
                        .onTapGesture(count: 1) { _ in
                            model.remoteControlAssistantStopPreview(user: .panel)
                            remoteControl.presentingPreview = false
                        }
                } else {
                    Text("No preview received yet.")
                }
            } else {
                TextButtonView("Show") {
                    model.remoteControlAssistantStartPreview(user: .panel)
                    remoteControl.presentingPreview = true
                }
            }
        } header: {
            Text(title)
        } footer: {
            if remoteControl.presentingPreview {
                Text("Tap the preview to hide it. Double tap to toggle full screen.")
            }
        }
        Section {
            if let status = remoteControl.general {
                VStack(alignment: .leading, spacing: 3) {
                    StatusItemView(
                        icon: "battery.0",
                        status: batteryStatus(status: status)
                    )
                    StatusItemView(icon: "flame", status: flameStatus(status: status))
                    StatusItemView(icon: "wifi", status: ssidStatus(status: status))
                }
            } else {
                Text("No status received yet.")
            }
        } header: {
            Text("General")
        }
        Section {
            if let status = remoteControl.topLeft {
                VStack(alignment: .leading, spacing: 3) {
                    StatusItemView(
                        icon: "dot.radiowaves.left.and.right",
                        status: status.stream
                    )
                    StatusItemView(icon: "camera", status: status.camera)
                    StatusItemView(icon: "music.mic", status: status.mic)
                    StatusItemView(icon: "magnifyingglass", status: status.zoom)
                    StatusItemView(icon: "xserve", status: status.obs)
                    StatusItemView(icon: "megaphone", status: status.events)
                    StatusItemView(icon: "message", status: status.chat)
                    StatusItemView(icon: "eye", status: status.viewers)
                }
            } else {
                Text("No status received yet.")
            }
        } header: {
            Text("Top left")
        }
        Section {
            if let status = remoteControl.topRight {
                VStack(alignment: .leading, spacing: 3) {
                    if let audioInfo = status.audioInfo {
                        RemoteControlAudioLevelView(
                            level: audioInfo.audioLevel.toFloat(),
                            channels: audioInfo.numberOfAudioChannels
                        )
                    } else {
                        // Backwards compatibility. Remove later.
                        StatusItemView(icon: "waveform", status: status.audioLevel)
                    }
                    StatusItemView(icon: "cpu", status: status.systemMonitor)
                    StatusItemView(icon: "server.rack", status: status.rtmpServer)
                    StatusItemView(icon: "app.connected.to.app.below.fill", status: status.moblink)
                    StatusItemView(icon: "appletvremote.gen1", status: status.remoteControl)
                    StatusItemView(icon: "appletvremote.gen1", status: status.djiDevices)
                    StatusItemView(icon: "gamecontroller", status: status.gameController)
                    StatusItemView(icon: "speedometer", status: status.bitrate)
                    StatusItemView(icon: "deskclock", status: status.uptime)
                    StatusItemView(icon: "location", status: status.location)
                    StatusItemView(icon: "phone.connection", status: status.srtla)
                    StatusItemView(icon: "phone.connection", status: status.srtlaRtts)
                    StatusItemView(icon: "record.circle", status: status.recording)
                    StatusItemView(icon: "play", status: status.replay)
                    StatusItemView(icon: "globe", status: status.browserWidgets)
                }
            } else {
                Text("No status received yet.")
            }
        } header: {
            Text("Top right")
        }
    }
}

private struct LiveView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl
    @State private var presentingConfirm: Bool = false
    @State private var pendingStreaming: Bool = false

    var body: some View {
        Toggle("Live", isOn: Binding(
            get: { remoteControl.streaming },
            set: { streaming in
                guard streaming != model.remoteControlAssistantStreamerState.streaming else {
                    return
                }
                pendingStreaming = streaming
                presentingConfirm = true
            }
        ))
        .confirmationDialog("", isPresented: $presentingConfirm) {
            Button(pendingStreaming ? "Go Live" : "End") {
                model.remoteControlAssistantSetStream(on: pendingStreaming)
                remoteControl.streaming = pendingStreaming
            }
        }
    }
}

private struct RecordingView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl
    @State private var presentingConfirm: Bool = false
    @State private var pendingRecording: Bool = false

    var body: some View {
        Toggle("Recording", isOn: Binding(
            get: { remoteControl.recording },
            set: { recording in
                guard recording != model.remoteControlAssistantStreamerState.recording else {
                    return
                }
                pendingRecording = recording
                presentingConfirm = true
            }
        ))
        .confirmationDialog("", isPresented: $presentingConfirm) {
            Button(pendingRecording ? "Start recording" : "Stop recording") {
                model.remoteControlAssistantSetRecord(on: pendingRecording)
                remoteControl.recording = pendingRecording
            }
        }
    }
}

private struct MutedView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Toggle("Muted", isOn: $remoteControl.muted)
            .onChange(of: remoteControl.muted) {
                guard remoteControl.muted != model.remoteControlAssistantStreamerState.muted else {
                    return
                }
                model.remoteControlAssistantSetMute(on: $0)
            }
    }
}

private struct ZoomView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    private func submitZoom(value: String) {
        guard let x = Float(value) else {
            if let zoom = model.remoteControlAssistantStreamerState.zoom {
                remoteControl.zoom = String(zoom)
            }
            return
        }
        model.remoteControlAssistantSetZoom(x: x)
    }

    var body: some View {
        HStack {
            Text("Zoom")
            Spacer()
            TextField("", text: $remoteControl.zoom)
                .multilineTextAlignment(.trailing)
                .disableAutocorrection(true)
                .onSubmit {
                    guard let zoom = model.remoteControlAssistantStreamerState.zoom else {
                        return
                    }
                    guard remoteControl.zoom != String(zoom) else {
                        return
                    }
                    submitZoom(value: remoteControl.zoom)
                }
        }
        Picker("", selection: $remoteControl.zoomPreset) {
            ForEach(remoteControl.zoomPresets) {
                Text($0.name)
            }
            .onChange(of: remoteControl.zoomPreset) { _ in
                guard remoteControl.zoomPreset != model.remoteControlAssistantStreamerState.zoomPreset else {
                    return
                }
                model.remoteControlAssistantSetZoomPreset(id: remoteControl.zoomPreset)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct ScenePickerView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.scene) {
            ForEach(remoteControl.settings?.scenes ?? []) {
                Text($0.name)
                    .tag($0.id)
            }
        } label: {
            Text("Scene")
        }
        .onChange(of: remoteControl.scene) { _ in
            guard remoteControl.scene != model.remoteControlAssistantStreamerState.scene else {
                return
            }
            model.remoteControlAssistantSetScene(id: remoteControl.scene)
        }
    }
}

private struct AutoSceneSwitcherPickerView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.autoSceneSwitcher) {
            Text("-- None --")
                .tag(nil as UUID?)
            ForEach(remoteControl.settings?.autoSceneSwitchers ?? []) {
                Text($0.name)
                    .tag($0.id as UUID?)
            }
        } label: {
            Text("Auto scene switcher")
        }
        .onChange(of: remoteControl.autoSceneSwitcher) { _ in
            guard remoteControl.autoSceneSwitcher
                != model.remoteControlAssistantStreamerState.autoSceneSwitcher?.id
            else {
                return
            }
            model.remoteControlAssistantSetAutoSceneSwitcher(id: remoteControl.autoSceneSwitcher)
        }
    }
}

private struct MicView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.mic) {
            ForEach(remoteControl.settings?.mics ?? []) {
                Text($0.name)
                    .tag($0.id)
            }
        } label: {
            Text("Mic")
        }
        .onChange(of: remoteControl.mic) { _ in
            guard remoteControl.mic != model.remoteControlAssistantStreamerState.mic else {
                return
            }
            model.remoteControlAssistantSetMic(id: remoteControl.mic)
        }
    }
}

private struct BitrateView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.bitrate) {
            ForEach(remoteControl.settings?.bitratePresets ?? []) { preset in
                Text(preset.bitrate > 0 ? formatBytesPerSecond(speed: Int64(preset.bitrate)) : "Unknown")
                    .tag(preset.id)
            }
        } label: {
            Text("Bitrate")
        }
        .onChange(of: remoteControl.bitrate) { _ in
            guard remoteControl.bitrate != model.remoteControlAssistantStreamerState.bitrate else {
                return
            }
            model.remoteControlAssistantSetBitratePreset(id: remoteControl.bitrate)
        }
    }
}

private struct GimbalPresetView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    if let presets = remoteControl.settings?.gimbalPresets, !presets.isEmpty {
                        ForEach(presets) { preset in
                            TextButtonView(title: preset.name) {
                                model.remoteControlAssistantMoveToGimbalPreset(id: preset.id)
                            }
                        }
                    } else {
                        HCenter {
                            Text("No gimbal presets configured in streamer")
                        }
                    }
                }
            }
            .navigationTitle("Gimbal presets")
        } label: {
            Text("Gimbal presets")
        }
    }
}

private struct SrtConnectionPrioritiesView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        if let settings = remoteControl.settings {
            NavigationLink {
                RemoteControlSrtConnectionPrioritiesView(
                    model: model,
                    srt: settings.srt,
                    enabled: settings.srt.connectionPrioritiesEnabled
                )
            } label: {
                Text("SRT connection priorities")
            }
        }
    }
}

private struct FilterToggleView: View {
    let model: Model
    let filter: RemoteControlFilter
    @Binding var value: Bool

    var body: some View {
        Toggle(filter.toString(), isOn: $value)
            .onChange(of: value) { _ in
                guard value != model.remoteControlAssistantStreamerState.filters?[filter] else {
                    return
                }
                model.remoteControlAssistantSetFilter(filter: filter, on: value)
            }
    }
}

private struct FiltersView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    FilterToggleView(model: model, filter: .pixellate, value: $remoteControl.pixellate)
                    FilterToggleView(model: model, filter: .movie, value: $remoteControl.movie)
                    FilterToggleView(model: model, filter: .grayScale, value: $remoteControl.grayScale)
                    FilterToggleView(model: model, filter: .sepia, value: $remoteControl.sepia)
                    FilterToggleView(model: model, filter: .triple, value: $remoteControl.triple)
                    FilterToggleView(model: model, filter: .twin, value: $remoteControl.twin)
                    FilterToggleView(model: model, filter: .fourThree, value: $remoteControl.fourThree)
                    FilterToggleView(model: model, filter: .pinch, value: $remoteControl.pinch)
                    FilterToggleView(model: model, filter: .whirlpool, value: $remoteControl.whirlpool)
                    FilterToggleView(model: model, filter: .poll, value: $remoteControl.poll)
                    FilterToggleView(model: model, filter: .blurFaces, value: $remoteControl.blurFaces)
                    FilterToggleView(model: model, filter: .privacy, value: $remoteControl.privacy)
                    FilterToggleView(model: model, filter: .beauty, value: $remoteControl.beauty)
                    FilterToggleView(
                        model: model,
                        filter: .moblinInMouth,
                        value: $remoteControl.moblinInMouth
                    )
                    FilterToggleView(model: model, filter: .cameraMan, value: $remoteControl.cameraMan)
                }
            }
            .navigationTitle("Filters")
        } label: {
            Text("Filters")
        }
    }
}

private struct DebugLoggingView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Toggle("Debug logging", isOn: $remoteControl.debugLogging)
            .onChange(of: remoteControl.debugLogging) { _ in
                guard remoteControl.debugLogging != model.remoteControlAssistantStreamerState.debugLogging
                else {
                    return
                }
                model.remoteControlAssistantSetDebugLogging(on: remoteControl.debugLogging)
            }
    }
}

private struct ControlBarRemoteControlAssistantControlView: View {
    let model: Model
    @ObservedObject var remoteControl: RemoteControl
    var title: LocalizedStringKey = ""
    @State private var presentingLog: Bool = false
    @State private var log: Deque<LogEntry> = []

    private func reloadLog() {
        log = model.remoteControlAssistantLog
    }

    var body: some View {
        Section {
            if remoteControl.settings != nil {
                LiveView(model: model, remoteControl: remoteControl)
                RecordingView(model: model, remoteControl: remoteControl)
                MutedView(model: model, remoteControl: remoteControl)
                ZoomView(model: model, remoteControl: remoteControl)
                ScenePickerView(model: model, remoteControl: remoteControl)
                AutoSceneSwitcherPickerView(model: model, remoteControl: remoteControl)
                MicView(model: model, remoteControl: remoteControl)
                BitrateView(model: model, remoteControl: remoteControl)
                SrtConnectionPrioritiesView(model: model, remoteControl: remoteControl)
                GimbalPresetView(model: model, remoteControl: remoteControl)
                FiltersView(model: model, remoteControl: remoteControl)
                DebugLoggingView(model: model, remoteControl: remoteControl)
            } else {
                HCenter {
                    ProgressView()
                }
            }
        } header: {
            Text(title)
        }
        Section {
            TextButtonView("Reload browser widgets") {
                model.remoteControlAssistantReloadBrowserWidgets()
            }
            TextButtonView("Refresh status") {
                model.updateRemoteControlAssistantStatus()
            }
            TextButtonView("Log") {
                presentingLog = true
            }
            .fullScreenCover(isPresented: $presentingLog) {
                DebugLogSettingsView(model: model,
                                     debug: model.database.debug,
                                     log: $log,
                                     presentingLog: $presentingLog,
                                     reloadLog: reloadLog,
                                     clearLog: { model.clearRemoteControlAssistantLog() })
                    .task {
                        reloadLog()
                    }
            }
        }
    }
}

private struct StreamerSelectionButtonView: View {
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Button {
            remoteControl.presentingStreamers = true
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: "person")
                    .foregroundStyle(.foreground)
                    .frame(width: 12, height: 12)
                    .padding()
                    .glassEffect()
                    .padding(2)
            } else {
                Image(systemName: "person")
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(.gray)
                    )
                    .foregroundStyle(.gray)
                    .padding(7)
            }
        }
    }
}

private struct ButtonsView: View {
    let model: Model

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                HStack(spacing: 0) {
                    StreamerSelectionButtonView(remoteControl: model.remoteControl)
                    CloseButtonView {
                        model.showingRemoteControl = false
                        model.setQuickButton(type: .remote, isOn: model.showingRemoteControl)
                        model.updateQuickButtonStates()
                    }
                }
                Spacer()
            }
        }
    }
}

private struct StreamerNotConfiguredView: View {
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            Text("No streamer selected.")
            Spacer()
        }
    }
}

private struct WaitingForStreamerView: View {
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            Text("Waiting for the remote control streamer to connect...")
            Spacer()
        }
    }
}

private struct ControlBarRemoteControlAssistantInnerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControlSettings: SettingsRemoteControl
    @ObservedObject var remoteControl: RemoteControl
    @ObservedObject var orientation: Orientation
    @State var didDetachCamera = false

    var body: some View {
        ZStack {
            if remoteControl.presentingPreviewFullScreen {
                if !model.isRemoteControlAssistantConfigured() {
                    StreamerNotConfiguredView()
                } else if model.isRemoteControlAssistantConnected() {
                    if let preview = remoteControl.preview {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .onTapGesture(count: 2) { _ in
                                remoteControl.presentingPreviewFullScreen = false
                            }
                    } else {
                        Text("No preview received yet.")
                    }
                } else {
                    WaitingForStreamerView()
                }
            } else {
                HStack(spacing: 0) {
                    if !model.isRemoteControlAssistantConfigured() {
                        StreamerNotConfiguredView()
                    } else if !model.isRemoteControlAssistantConnected() {
                        WaitingForStreamerView()
                    } else if orientation.isPortrait {
                        NavigationStack {
                            Form {
                                ControlBarRemoteControlAssistantStatusView(model: model,
                                                                           remoteControl: remoteControl,
                                                                           title: "Preview")
                                ControlBarRemoteControlAssistantControlView(model: model,
                                                                            remoteControl: remoteControl,
                                                                            title: "Control")
                            }
                            .navigationTitle(" ")
                            .navigationBarTitleDisplayMode(.inline)
                        }
                    } else {
                        NavigationStack {
                            Form {
                                ControlBarRemoteControlAssistantStatusView(model: model,
                                                                           remoteControl: remoteControl)
                            }
                            .navigationTitle("Status")
                            .navigationBarTitleDisplayMode(.inline)
                        }
                        NavigationStack {
                            Form {
                                ControlBarRemoteControlAssistantControlView(model: model,
                                                                            remoteControl: remoteControl)
                            }
                            .navigationTitle("Control")
                            .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                }
            }
        }
        .onAppear {
            model.updateRemoteControlAssistantStatus()
            didDetachCamera = !(model.isLive || model.isRecording)
            if didDetachCamera {
                model.detachCamera()
            }
            model.updateScreenAutoOff()
            if remoteControl.presentingPreview {
                model.remoteControlAssistantStartPreview(user: .panel)
            }
            model.remoteControlAssistantStartStatus()
        }
        .onDisappear {
            if didDetachCamera {
                model.attachCamera()
            }
            model.updateScreenAutoOff()
            model.remoteControlAssistantStopPreview(user: .panel)
            model.remoteControlAssistantStopStatus()
        }
        .sheet(isPresented: $remoteControl.presentingStreamers) {
            NavigationStack {
                Form {
                    RemoteControlStreamersView(
                        model: model,
                        remoteControlSettings: model.database.remoteControl
                    )
                }
                .navigationTitle("Streamers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    CloseToolbar(presenting: $remoteControl.presentingStreamers)
                }
            }
        }
    }
}

struct ControlBarRemoteControlAssistantView: View {
    let model: Model
    @ObservedObject var remoteControlSettings: SettingsRemoteControl

    private func title() -> String {
        if let streamerName = remoteControlSettings.getSelectedStreamerName() {
            return String(localized: "Remote control assistant") + " (\(streamerName))"
        } else {
            return String(localized: "Remote control assistant")
        }
    }

    var body: some View {
        ZStack {
            ControlBarRemoteControlAssistantInnerView(remoteControlSettings: model.database.remoteControl,
                                                      remoteControl: model.remoteControl,
                                                      orientation: model.orientation)
            VStack(alignment: .center) {
                Text(title())
                    .font(.title3)
                    .padding(5)
                Spacer()
            }
            ButtonsView(model: model)
        }
        .background(Color(.systemGroupedBackground))
    }
}
