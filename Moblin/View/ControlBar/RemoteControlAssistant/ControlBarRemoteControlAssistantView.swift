import SwiftUI

private struct StatusItemView: View {
    var icon: String
    var status: RemoteControlStatusItem?

    var body: some View {
        if let status {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(status.ok ? .primary : .red)
                    .frame(width: 20)
                Text(status.message)
            }
            .font(smallFont)
        } else {
            EmptyView()
        }
    }
}

private struct RemoteControlSrtConnectionPriorityView: View {
    @EnvironmentObject var model: Model
    let priority: RemoteControlSettingsSrtConnectionPriority
    @State var enabled: Bool
    @State var prio: Float

    private func makeName() -> String {
        if let name = model.database.networkInterfaceNames!.first(where: { interface in
            interface.interfaceName == priority.name
        })?.name, !name.isEmpty {
            return name
        } else {
            return priority.name
        }
    }

    var body: some View {
        Toggle(isOn: Binding(get: {
            enabled
        }, set: { value in
            var priority = priority
            priority.enabled = value
            enabled = value
            model.remoteControlAssistantSetSrtConnectionPriority(priority: priority)
        })) {
            HStack {
                Text(makeName())
                    .frame(width: 90)
                Slider(
                    value: $prio,
                    in: Float(minimumSrtConnectionPriority) ... Float(maximumSrtConnectionPriority),
                    step: 1,
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
}

private struct RemoteControlSrtConnectionPrioritiesView: View {
    @EnvironmentObject var model: Model
    var srt: RemoteControlSettingsSrt
    @State var enabled: Bool

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    enabled
                }, set: { value in
                    enabled = value
                    model.remoteControlAssistantSetSrtConnectionPriorityEnabled(enabled: value)
                })) {
                    Text("Enabled")
                }
            }
            Section {
                ForEach(srt.connectionPriorities) { priority in
                    RemoteControlSrtConnectionPriorityView(
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
                                .foregroundColor(.red)
                        } else {
                            Text(redText())
                                .foregroundColor(.red)
                            Text(yellowText())
                                .foregroundColor(.yellow)
                            Text(greenText())
                                .foregroundColor(.green)
                        }
                    }
                    .padding([.bottom], 3)
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

private struct ControlBarRemoteControlAssistantLeftView: View {
    @EnvironmentObject var model: Model

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
        Form {
            Section {
                if model.remoteControlAssistantShowPreview {
                    if let preview = model.remoteControlPreview {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .padding([.bottom], 3)
                            .onTapGesture(count: 2) { _ in
                                model.remoteControlAssistantShowPreviewFullScreen = true
                            }
                            .onTapGesture(count: 1) { _ in
                                model.remoteControlAssistantStopPreview(user: .panel)
                                model.remoteControlAssistantShowPreview = false
                            }
                    } else {
                        Text("No preview received yet.")
                    }
                } else {
                    Button {
                        model.remoteControlAssistantStartPreview(user: .panel)
                        model.remoteControlAssistantShowPreview = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Show")
                            Spacer()
                        }
                    }
                }
            } header: {
                Text("Preview")
            } footer: {
                if model.remoteControlAssistantShowPreview {
                    Text("Tap the preview to hide it. Double tap to toggle full screen.")
                }
            }
            Section {
                if let status = model.remoteControlGeneral {
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
                if let status = model.remoteControlTopLeft {
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
                if let status = model.remoteControlTopRight {
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
                        StatusItemView(icon: "server.rack", status: status.rtmpServer)
                        StatusItemView(icon: "app.connected.to.app.below.fill", status: status.moblink)
                        StatusItemView(
                            icon: "appletvremote.gen1",
                            status: status.remoteControl
                        )
                        StatusItemView(icon: "gamecontroller", status: status.gameController)
                        StatusItemView(icon: "speedometer", status: status.bitrate)
                        StatusItemView(icon: "deskclock", status: status.uptime)
                        StatusItemView(icon: "location", status: status.location)
                        StatusItemView(icon: "phone.connection", status: status.srtla)
                        StatusItemView(icon: "record.circle", status: status.recording)
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
}

private struct LiveView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.remoteControlState.streaming ?? false
        }, set: { value in
            pendingValue = value
            isPresentingConfirm = true
        })) {
            Text("Live")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? String(localized: "Go Live") : String(localized: "End")) {
                model.remoteControlAssistantSetStream(on: pendingValue)
            }
        }
    }
}

private struct RecordingView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.remoteControlState.recording ?? false
        }, set: { value in
            pendingValue = value
            isPresentingConfirm = true
        })) {
            Text("Recording")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? String(localized: "Start") : String(localized: "Stop")) {
                model.remoteControlAssistantSetRecord(on: pendingValue)
            }
        }
    }
}

private struct ZoomView: View {
    @EnvironmentObject var model: Model

    private func submitZoom(value: String) {
        guard let x = Float(value) else {
            if let zoom = model.remoteControlState.zoom {
                model.remoteControlZoom = String(zoom)
            }
            return
        }
        model.remoteControlAssistantSetZoom(x: x)
    }

    var body: some View {
        HStack {
            Text("Zoom")
            Spacer()
            TextField("", text: $model.remoteControlZoom)
                .multilineTextAlignment(.trailing)
                .disableAutocorrection(true)
                .onSubmit {
                    guard let zoom = model.remoteControlState.zoom else {
                        return
                    }
                    guard model.remoteControlZoom != String(zoom) else {
                        return
                    }
                    submitZoom(value: model.remoteControlZoom)
                }
        }
    }
}

private struct ScenePickerView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Picker(selection: $model.remoteControlScene) {
            ForEach(model.remoteControlSettings?.scenes ?? []) { scene in
                Text(scene.name)
                    .tag(scene.id)
            }
        } label: {
            Text("Scene")
        }
        .onChange(of: model.remoteControlScene) { _ in
            guard model.remoteControlScene != model.remoteControlState.scene
            else {
                return
            }
            model.remoteControlAssistantSetScene(id: model.remoteControlScene)
        }
    }
}

private struct MicView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Picker(selection: $model.remoteControlMic) {
            ForEach(model.remoteControlSettings?.mics ?? []) { mic in
                Text(mic.name)
                    .tag(mic.id)
            }
        } label: {
            Text("Mic")
        }
        .onChange(of: model.remoteControlMic) { _ in
            guard model.remoteControlMic != model.remoteControlState.mic else {
                return
            }
            model.remoteControlAssistantSetMic(id: model.remoteControlMic)
        }
    }
}

private struct BitrateView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Picker(selection: $model.remoteControlBitrate) {
            ForEach(model.remoteControlSettings?.bitratePresets ?? []) { preset in
                Text(preset.bitrate > 0 ?
                    formatBytesPerSecond(speed: Int64(preset.bitrate)) :
                    "Unknown")
                    .tag(preset.id)
            }
        } label: {
            Text("Bitrate")
        }
        .onChange(of: model.remoteControlBitrate) { _ in
            guard model.remoteControlBitrate != model.remoteControlState.bitrate else {
                return
            }
            model.remoteControlAssistantSetBitratePreset(id: model.remoteControlBitrate)
        }
    }
}

private struct SrtConnectionPrioritiesView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if let settings = model.remoteControlSettings {
            NavigationLink {
                RemoteControlSrtConnectionPrioritiesView(
                    srt: settings.srt,
                    enabled: settings.srt.connectionPrioritiesEnabled
                )
            } label: {
                Text("SRT connection priorities")
            }
        }
    }
}

private struct DebugLoggingView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.remoteControlDebugLogging
        }, set: { value in
            model.remoteControlDebugLogging = value
            guard model.remoteControlDebugLogging != model.remoteControlState.debugLogging else {
                return
            }
            model.remoteControlAssistantSetDebugLogging(on: model.remoteControlDebugLogging)
        })) {
            Text("Debug logging")
        }
    }
}

private struct ControlBarRemoteControlAssistantRightView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                if model.remoteControlSettings != nil {
                    LiveView()
                    RecordingView()
                    ZoomView()
                    ScenePickerView()
                    MicView()
                    BitrateView()
                    SrtConnectionPrioritiesView()
                    DebugLoggingView()
                } else {
                    HCenter {
                        ProgressView()
                    }
                }
            } header: {
                Text("Control")
            }
            Section {
                Button {
                    model.remoteControlAssistantReloadBrowserWidgets()
                } label: {
                    HStack {
                        Text("")
                        Spacer()
                        Text("Reload browser widgets")
                        Spacer()
                    }
                }
                Section {
                    Button {
                        model.updateRemoteControlAssistantStatus()
                    } label: {
                        HStack {
                            Text("")
                            Spacer()
                            Text("Refresh status")
                            Spacer()
                        }
                    }
                }
            }
            Section {
                NavigationLink {
                    DebugLogSettingsView(
                        log: model.remoteControlAssistantLog,
                        formatLog: { model.formatLog(log: model.remoteControlAssistantLog) },
                        clearLog: {
                            model.clearRemoteControlAssistantLog()
                            model.objectWillChange.send()
                        }
                    )
                } label: {
                    Text("Log")
                }
            }
        }
    }
}

struct ControlBarRemoteControlAssistantView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            if model.remoteControlAssistantShowPreviewFullScreen {
                if model.isRemoteControlAssistantConnected() {
                    if let preview = model.remoteControlPreview {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .onTapGesture(count: 2) { _ in
                                model.remoteControlAssistantShowPreviewFullScreen = false
                            }
                    } else {
                        Text("No preview received yet.")
                    }
                } else {
                    Text("Waiting for the remote control streamer to connect...")
                }
            } else {
                HStack(spacing: 0) {
                    if !model.isRemoteControlAssistantConnected() {
                        Form {
                            Text("Waiting for the remote control streamer to connect...")
                        }
                    } else {
                        ControlBarRemoteControlAssistantLeftView()
                        ControlBarRemoteControlAssistantRightView()
                    }
                }
            }
        }
        .onAppear {
            model.updateRemoteControlAssistantStatus()
            if !(model.isLive || model.isRecording) {
                model.detachCamera()
            }
            model.updateScreenAutoOff()
            if model.remoteControlAssistantShowPreview {
                model.remoteControlAssistantStartPreview(user: .panel)
            }
        }
        .onDisappear {
            if !(model.isLive || model.isRecording) {
                model.attachCamera()
            }
            model.updateScreenAutoOff()
            model.remoteControlAssistantStopPreview(user: .panel)
        }
        .navigationTitle("Remote control assistant")
    }
}
