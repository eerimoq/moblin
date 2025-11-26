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
        if let name = model.database.networkInterfaceNames.first(where: { interface in
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
        }, set: {
            var priority = priority
            priority.enabled = $0
            enabled = $0
            model.remoteControlAssistantSetSrtConnectionPriority(priority: priority)
        })) {
            HStack {
                Text(makeName())
                    .frame(width: 90)
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
                }, set: {
                    enabled = $0
                    model.remoteControlAssistantSetSrtConnectionPriorityEnabled(enabled: $0)
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

private struct ControlBarRemoteControlAssistantStatusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

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
            if remoteControl.assistantShowPreview {
                if let preview = remoteControl.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding([.bottom], 3)
                        .onTapGesture(count: 2) { _ in
                            remoteControl.assistantShowPreviewFullScreen = true
                        }
                        .onTapGesture(count: 1) { _ in
                            model.remoteControlAssistantStopPreview(user: .panel)
                            remoteControl.assistantShowPreview = false
                        }
                } else {
                    Text("No preview received yet.")
                }
            } else {
                TextButtonView("Show") {
                    model.remoteControlAssistantStartPreview(user: .panel)
                    remoteControl.assistantShowPreview = true
                }
            }
        } header: {
            Text("Preview")
        } footer: {
            if remoteControl.assistantShowPreview {
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
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.remoteControlState.streaming ?? false
        }, set: {
            pendingValue = $0
            isPresentingConfirm = true
        })) {
            Text("Live")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? "Go Live" : "End") {
                model.remoteControlAssistantSetStream(on: pendingValue)
            }
        }
    }
}

private struct RecordingView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.remoteControlState.recording ?? false
        }, set: {
            pendingValue = $0
            isPresentingConfirm = true
        })) {
            Text("Recording")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? "Start recording" : "Stop recording") {
                model.remoteControlAssistantSetRecord(on: pendingValue)
            }
        }
    }
}

private struct MutedView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Toggle(isOn: Binding(get: {
            remoteControl.muted
        }, set: {
            model.remoteControlAssistantSetMute(on: $0)
        })) {
            Text("Muted")
        }
    }
}

private struct ZoomView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    private func submitZoom(value: String) {
        guard let x = Float(value) else {
            if let zoom = model.remoteControlState.zoom {
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
                    guard let zoom = model.remoteControlState.zoom else {
                        return
                    }
                    guard remoteControl.zoom != String(zoom) else {
                        return
                    }
                    submitZoom(value: remoteControl.zoom)
                }
        }
        Picker("", selection: $remoteControl.zoomPreset) {
            ForEach(remoteControl.zoomPresets) { preset in
                Text(preset.name)
            }
            .onChange(of: remoteControl.zoomPreset) { _ in
                guard remoteControl.zoomPreset != model.remoteControlState.zoomPreset else {
                    return
                }
                model.remoteControlAssistantSetZoomPreset(id: remoteControl.zoomPreset)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct ScenePickerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.scene) {
            ForEach(remoteControl.settings?.scenes ?? []) { scene in
                Text(scene.name)
                    .tag(scene.id)
            }
        } label: {
            Text("Scene")
        }
        .onChange(of: remoteControl.scene) { _ in
            guard remoteControl.scene != model.remoteControlState.scene else {
                return
            }
            model.remoteControlAssistantSetScene(id: remoteControl.scene)
        }
    }
}

private struct AutoSceneSwitcherPickerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.autoSceneSwitcher) {
            Text("-- None --")
                .tag(nil as UUID?)
            ForEach(remoteControl.settings?.autoSceneSwitchers ?? []) { autoSceneSwitcher in
                Text(autoSceneSwitcher.name)
                    .tag(autoSceneSwitcher.id as UUID?)
            }
        } label: {
            Text("Auto scene switcher")
        }
        .onChange(of: remoteControl.autoSceneSwitcher) { _ in
            guard remoteControl.autoSceneSwitcher != model.remoteControlState.autoSceneSwitcher?.id else {
                return
            }
            model.remoteControlAssistantSetAutoSceneSwitcher(id: remoteControl.autoSceneSwitcher)
        }
    }
}

private struct MicView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.mic) {
            ForEach(remoteControl.settings?.mics ?? []) { mic in
                Text(mic.name)
                    .tag(mic.id)
            }
        } label: {
            Text("Mic")
        }
        .onChange(of: remoteControl.mic) { _ in
            guard remoteControl.mic != model.remoteControlState.mic else {
                return
            }
            model.remoteControlAssistantSetMic(id: remoteControl.mic)
        }
    }
}

private struct BitrateView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Picker(selection: $remoteControl.bitrate) {
            ForEach(remoteControl.settings?.bitratePresets ?? []) { preset in
                Text(preset.bitrate > 0 ?
                    formatBytesPerSecond(speed: Int64(preset.bitrate)) :
                    "Unknown")
                    .tag(preset.id)
            }
        } label: {
            Text("Bitrate")
        }
        .onChange(of: remoteControl.bitrate) { _ in
            guard remoteControl.bitrate != model.remoteControlState.bitrate else {
                return
            }
            model.remoteControlAssistantSetBitratePreset(id: remoteControl.bitrate)
        }
    }
}

private struct SrtConnectionPrioritiesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        if let settings = remoteControl.settings {
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
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Toggle(isOn: Binding(get: {
            remoteControl.debugLogging
        }, set: {
            remoteControl.debugLogging = $0
            guard remoteControl.debugLogging != model.remoteControlState.debugLogging else {
                return
            }
            model.remoteControlAssistantSetDebugLogging(on: remoteControl.debugLogging)
        })) {
            Text("Debug logging")
        }
    }
}

private struct ControlBarRemoteControlAssistantControlView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl
    @State var presentingLog: Bool = false
    @State var log: Deque<LogEntry> = []

    var body: some View {
        Section {
            if remoteControl.settings != nil {
                LiveView(remoteControl: remoteControl)
                RecordingView(remoteControl: remoteControl)
                MutedView(remoteControl: remoteControl)
                ZoomView(remoteControl: remoteControl)
                ScenePickerView(remoteControl: remoteControl)
                AutoSceneSwitcherPickerView(remoteControl: remoteControl)
                MicView(remoteControl: remoteControl)
                BitrateView(remoteControl: remoteControl)
                SrtConnectionPrioritiesView(remoteControl: remoteControl)
                DebugLoggingView(remoteControl: remoteControl)
            } else {
                HCenter {
                    ProgressView()
                }
            }
        } header: {
            Text("Control")
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
                                     log: $log,
                                     presentingLog: $presentingLog,
                                     clearLog: { model.clearRemoteControlAssistantLog() })
                    .task {
                        log = model.remoteControlAssistantLog
                    }
            }
        }
    }
}

private struct StreamerSelectionButtonView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControl: RemoteControl

    var body: some View {
        Button {
            remoteControl.assistantShowStreamers = true
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: "person")
                    .foregroundStyle(.primary)
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
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                HStack(spacing: 0) {
                    StreamerSelectionButtonView(remoteControl: model.remoteControl)
                    CloseButtonView {
                        model.showingRemoteControl = false
                        model.setGlobalButtonState(type: .remote, isOn: model.showingRemoteControl)
                        model.updateQuickButtonStates()
                    }
                }
                Spacer()
            }
        }
    }
}

private struct StreamersToolbar: ToolbarContent {
    @ObservedObject var remoteControl: RemoteControl

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                remoteControl.assistantShowStreamers = false
            } label: {
                Image(systemName: "xmark")
            }
        }
    }
}

private struct StreamerNotConfiguredView: View {
    var body: some View {
        Text("No streamer selected.")
    }
}

private struct WaitingForStreamerView: View {
    var body: some View {
        Text("Waiting for the remote control streamer to connect...")
    }
}

private struct ControlBarRemoteControlAssistantInnerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControlSettings: SettingsRemoteControl
    @ObservedObject var remoteControl: RemoteControl
    @ObservedObject var orientation: Orientation
    @State var didDetachCamera = false

    private func title() -> String {
        if let streamerName = remoteControlSettings.getSelectedStreamerName() {
            return String(localized: "Remote control assistant") + " (\(streamerName))"
        } else {
            return String(localized: "Remote control assistant")
        }
    }

    var body: some View {
        ZStack {
            if remoteControl.assistantShowPreviewFullScreen {
                if !model.isRemoteControlAssistantConfigured() {
                    StreamerNotConfiguredView()
                } else if model.isRemoteControlAssistantConnected() {
                    if let preview = remoteControl.preview {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .onTapGesture(count: 2) { _ in
                                remoteControl.assistantShowPreviewFullScreen = false
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
                        Form {
                            StreamerNotConfiguredView()
                        }
                    } else if !model.isRemoteControlAssistantConnected() {
                        Form {
                            WaitingForStreamerView()
                        }
                    } else if orientation.isPortrait {
                        Form {
                            ControlBarRemoteControlAssistantStatusView(remoteControl: remoteControl)
                            ControlBarRemoteControlAssistantControlView(remoteControl: remoteControl)
                        }
                    } else {
                        Form {
                            ControlBarRemoteControlAssistantStatusView(remoteControl: remoteControl)
                        }
                        Form {
                            ControlBarRemoteControlAssistantControlView(remoteControl: remoteControl)
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
            if remoteControl.assistantShowPreview {
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
        .sheet(isPresented: $remoteControl.assistantShowStreamers) {
            NavigationStack {
                Form {
                    RemoteControlStreamersView(remoteControlSettings: model.database.remoteControl,
                                               remoteControl: model.remoteControl)
                }
                .navigationTitle("Streamers")
                .toolbar {
                    StreamersToolbar(remoteControl: remoteControl)
                }
            }
        }
        .navigationTitle(title())
    }
}

struct ControlBarRemoteControlAssistantView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            NavigationStack {
                ControlBarRemoteControlAssistantInnerView(remoteControlSettings: model.database.remoteControl,
                                                          remoteControl: model.remoteControl,
                                                          orientation: model.orientation)
            }
            ButtonsView()
        }
    }
}
