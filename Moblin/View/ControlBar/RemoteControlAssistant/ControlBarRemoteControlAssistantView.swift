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
    let defaultAudioLevel: Float = -160.0

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
                if let channels {
                    Text(formatAudioLevelChannels(channels: channels))
                }
                if level.isNaN {
                    if channels == nil {
                        Text("Muted")
                    } else {
                        Text(",Muted")
                    }
                } else if level == .infinity {
                    if channels == nil {
                        Text("Unknown")
                    } else {
                        Text(",Unknown")
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
            }
            .font(smallFont)
        }
    }
}

struct ControlBarRemoteControlAssistantView: View {
    @EnvironmentObject var model: Model
    var done: () -> Void

    private func submitZoom(value: String) {
        guard let x = Float(value) else {
            if let zoom = model.remoteControlState.zoom {
                model.remoteControlZoom = String(zoom)
            }
            return
        }
        model.remoteControlAssistantSetZoom(x: x)
    }

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

    private func audioStatus(status: RemoteControlStatusTopRight) -> Float {
        guard let audioLevel = status.audioLevel?.toFloat() else {
            return .infinity
        }
        return audioLevel
    }

    var body: some View {
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
                                            model.remoteControlAssistantShowPreview = false
                                        }
                                } else {
                                    Text("No preview received yet.")
                                }
                            } else {
                                Button {
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
                                    StatusItemView(icon: "battery.0", status: batteryStatus(status: status))
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
                                    RemoteControlAudioLevelView(
                                        level: audioStatus(status: status),
                                        channels: status.numberOfAudioChannels
                                    )
                                    StatusItemView(icon: "server.rack", status: status.rtmpServer)
                                    StatusItemView(icon: "appletvremote.gen1", status: status.remoteControl)
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
                    Form {
                        Section {
                            if let settings = model.remoteControlSettings {
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
                                Picker(selection: $model.remoteControlScene) {
                                    ForEach(settings.scenes) { scene in
                                        Text(scene.name)
                                            .tag(scene.id)
                                    }
                                } label: {
                                    Text("Scene")
                                }
                                .onChange(of: model.remoteControlScene) { _ in
                                    guard model.remoteControlScene != model.remoteControlState.scene else {
                                        return
                                    }
                                    model.remoteControlAssistantSetScene(id: model.remoteControlScene)
                                }
                                Picker(selection: $model.remoteControlMic) {
                                    ForEach(settings.mics) { mic in
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
                                Picker(selection: $model.remoteControlBitrate) {
                                    ForEach(settings.bitratePresets) { preset in
                                        Text(preset
                                            .bitrate > 0 ?
                                            formatBytesPerSecond(speed: Int64(preset.bitrate)) :
                                            "Unknown")
                                            .tag(preset.id)
                                    }
                                } label: {
                                    Text("Bitrate")
                                }
                                .onChange(of: model.remoteControlBitrate) { _ in
                                    guard model.remoteControlBitrate != model.remoteControlState.bitrate
                                    else {
                                        return
                                    }
                                    model
                                        .remoteControlAssistantSetBitratePreset(id: model
                                            .remoteControlBitrate)
                                }
                                NavigationLink(destination: RemoteControlSrtConnectionPrioritiesView(
                                    srt: settings
                                        .srt,
                                    enabled: settings.srt.connectionPrioritiesEnabled
                                )) {
                                    Text("SRT connection priorities")
                                }
                            } else {
                                Text("No settings received yet.")
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
                            NavigationLink(destination: DebugLogSettingsView(
                                log: model.remoteControlAssistantLog,
                                formatLog: { model.formatLog(log: model.remoteControlAssistantLog) },
                                clearLog: { model.clearRemoteControlAssistantLog() },
                                quickDone: done
                            )) {
                                Text("Log")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Remote control assistant")
            .toolbar {
                SettingsToolbar(quickDone: done)
            }
        }
    }
}
