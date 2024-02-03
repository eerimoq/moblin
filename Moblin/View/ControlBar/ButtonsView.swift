import AVFoundation
import SwiftUI

private let singleButtonSize: CGFloat = 45

struct ButtonImage: View {
    var state: ButtonState
    var buttonSize: CGFloat
    var slash: Bool = false
    var pause: Bool = false
    var overlayColor: Color = .white

    private func getImage(state: ButtonState) -> String {
        if state.isOn {
            return state.button.systemImageNameOn
        } else {
            return state.button.systemImageNameOff
        }
    }

    private var backgroundColor: Color {
        state.button.backgroundColor!.color()
    }

    var body: some View {
        let image = Image(systemName: getImage(state: state))
            .frame(width: buttonSize, height: buttonSize)
            .foregroundColor(.white)
            .background(backgroundColor)
            .clipShape(Circle())
        ZStack {
            if state.isOn {
                image.overlay(
                    Circle()
                        .stroke(.white)
                )
            } else {
                image
            }
            if slash {
                // Button press animation not perfect.
                Image(systemName: "line.diagonal")
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: 90))
                    .shadow(color: backgroundColor, radius: 0, x: 1, y: 0)
                    .shadow(color: backgroundColor, radius: 0, x: -1, y: 0)
                    .shadow(color: backgroundColor, radius: 0, x: 0, y: 1)
                    .shadow(color: backgroundColor, radius: 0, x: 0, y: -1)
                    .shadow(color: backgroundColor, radius: 0, x: -2, y: -2)
            }
            if pause {
                // Button press animation not perfect.
                Image(systemName: "pause")
                    .bold()
                    .font(.system(size: 9))
                    .frame(width: buttonSize, height: buttonSize)
                    .offset(y: -1)
                    .foregroundColor(overlayColor)
            }
        }
    }
}

struct ButtonPlaceholderImage: View {
    var body: some View {
        Button {} label: {
            Image(systemName: "pawprint")
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(.black)
        }
        .opacity(0.0)
    }
}

struct MicButtonView: View {
    @EnvironmentObject var model: Model
    @State var selectedMic: Mic
    var done: () -> Void
    @State var micFollowsScene: Bool = false
    @State var externalMicOverrides: Bool = false

    var body: some View {
        Form {
            Section {
                Picker("", selection: Binding(get: {
                    model.mic
                }, set: { mic, _ in
                    selectedMic = mic
                })) {
                    ForEach(model.listMics()) { mic in
                        Text(mic.name).tag(mic)
                    }
                }
                .onChange(of: selectedMic) { mic in
                    model.selectMicById(id: mic.id)
                    done()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if model.database.debug!.sceneMic! {
                Section {
                    Toggle("Mic follows scene", isOn: $micFollowsScene)
                    Toggle("External mic overrides follow scene toggle", isOn: $externalMicOverrides)
                }
            }
        }
        .navigationTitle("Mic")
        .toolbar {
            SettingsToolbar(quickDone: done)
        }
    }
}

struct StreamSwitcherView: View {
    @EnvironmentObject var model: Model
    var done: () -> Void

    var body: some View {
        Form {
            Section {
                Picker("", selection: $model.currentStreamId) {
                    ForEach(model.database.streams) { stream in
                        Text(stream.name)
                    }
                }
                .onChange(of: model.currentStreamId) { _ in
                    model.stopStream()
                    model.stopRecording()
                    if model.setCurrentStream(streamId: model.currentStreamId) {
                        model.reloadStream()
                        model.sceneUpdated()
                        model.isLive = true
                        DispatchQueue.main
                            .asyncAfter(deadline: .now() + 3) {
                                model.startStream(delayed: true)
                            }
                    } else {
                        model.makeErrorToast(title: "Failed to switch scene")
                    }
                    done()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("Automatically goes live when switching stream.")
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar(quickDone: done)
        }
    }
}

struct CameraView: View {
    @EnvironmentObject var model: Model
    var done: () -> Void

    var body: some View {
        Form {
            Section("Exposure bias") {
                HStack {
                    Slider(
                        value: $model.bias,
                        in: -2 ... 2,
                        step: 0.2,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.setExposureBias(bias: model.bias)
                        }
                    )
                    .onChange(of: model.bias) { _ in
                        model.setExposureBias(bias: model.bias)
                    }
                    Text("\(formatOneDecimal(value: model.bias)) EV")
                        .frame(width: 60)
                }
            }
        }
        .navigationTitle("Camera")
        .toolbar {
            SettingsToolbar(quickDone: done)
        }
    }
}

struct ObsView: View {
    @EnvironmentObject var model: Model
    var done: () -> Void
    @State private var isPresentingStartStreamingConfirm: Bool = false
    @State private var isPresentingStopStreamingConfirm: Bool = false

    private func submitAudioDelay(value: String) -> String {
        let offsetDouble = Double(value) ?? 0
        var offset = Int(offsetDouble)
        offset = offset.clamped(to: obsMinimumAudioDelay ... obsMaximumAudioDelay)
        model.setObsAudioDelay(offset: offset)
        return String(offset)
    }

    var body: some View {
        Form {
            if !model.isObsConnected() {
                Section {
                    Text("Unable to connect the OBS server. Retrying every 5 seconds.")
                }
            } else {
                if model.obsStreamingState == .stopped {
                    Section {
                        HStack {
                            Spacer()
                            Button(action: {
                                isPresentingStartStreamingConfirm = true
                            }, label: {
                                Text("Start streaming")
                            })
                            .confirmationDialog("", isPresented: $isPresentingStartStreamingConfirm) {
                                Button("Start") {
                                    model.obsStartStream()
                                }
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(RoundedRectangle(cornerRadius: 10)
                        .foregroundColor(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(.blue, lineWidth: 2)))
                } else if model.obsStreamingState == .starting {
                    Section {
                        HStack {
                            Spacer()
                            Text("Starting...")
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.gray)
                } else if model.obsStreamingState == .started {
                    Section {
                        HStack {
                            Spacer()
                            Button(action: {
                                isPresentingStopStreamingConfirm = true
                            }, label: {
                                Text("Stop streaming")
                            })
                            .confirmationDialog("", isPresented: $isPresentingStopStreamingConfirm) {
                                Button("Stop") {
                                    model.obsStopStream()
                                }
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                } else if model.obsStreamingState == .stopping {
                    Section {
                        HStack {
                            Spacer()
                            Text("Stopping...")
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.gray)
                } else {
                    Section {
                        HStack {
                            Spacer()
                            Text("Unknown streaming state.")
                            Spacer()
                        }
                    }
                }
                Section {
                    Picker("", selection: $model.obsCurrentScenePicker) {
                        ForEach(model.obsScenes, id: \.self) { scene in
                            Text(scene)
                        }
                    }
                    .onChange(of: model.obsCurrentScenePicker) { _ in
                        model.setObsScene(name: model.obsCurrentScenePicker)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Scenes")
                }
                if !model.stream.obsSourceName!.isEmpty {
                    Section {
                        ValueEditView(
                            title: "Delay",
                            value: "\(model.obsAudioDelay)",
                            minimum: Double(obsMinimumAudioDelay),
                            maximum: Double(min(obsMaximumAudioDelay, 9999)),
                            onSubmit: submitAudioDelay,
                            increment: 10,
                            unit: "ms"
                        )
                    } header: {
                        Text("\(model.stream.obsSourceName!) source audio sync")
                    }
                    Section {
                        if model.isLive {
                            if let image = model.obsScreenshot {
                                Image(image, scale: 1, label: Text(""))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Text("No snapshot received yet.")
                            }
                        } else {
                            Text("Go live to see snapshot.")
                        }
                    } header: {
                        Text("\(model.stream.obsSourceName!) source snapshot")
                    }
                    Section {
                        if model.isLive {
                            if !model.obsAudioVolume.isEmpty {
                                Text(model.obsAudioVolume)
                            } else {
                                Text("No audio levels received yet.")
                            }
                        } else {
                            Text("Go live to see audio levels.")
                        }
                    } header: {
                        Text("\(model.stream.obsSourceName!) source audio levels")
                    }
                } else {
                    Text("""
                    Configure source name in \
                    Settings → Streams → \(model.stream.name) → OBS remote control for \
                    snapshot and more.
                    """)
                }
            }
        }
        .navigationTitle("OBS remote control")
        .toolbar {
            SettingsToolbar(quickDone: done)
        }
    }
}

struct StatusItemView: View {
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

struct RemoteControlView: View {
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

    var body: some View {
        HStack {
            if !model.isRemoteControlAssistantConnected() {
                Form {
                    Text("Waiting for the remote control streamer to connect...")
                }
            } else {
                Form {
                    Section {
                        if let status = model.remoteControlGeneral {
                            VStack(alignment: .leading, spacing: 3) {
                                StatusItemView(icon: "battery.0", status: batteryStatus(status: status))
                                StatusItemView(icon: "flame", status: flameStatus(status: status))
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
                                StatusItemView(icon: "dot.radiowaves.left.and.right", status: status.stream)
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
                                StatusItemView(icon: "waveform", status: status.audioLevel)
                                StatusItemView(icon: "server.rack", status: status.rtmpServer)
                                StatusItemView(icon: "gamecontroller", status: status.gameController)
                                StatusItemView(icon: "speedometer", status: status.bitrate)
                                StatusItemView(icon: "deskclock", status: status.uptime)
                                StatusItemView(icon: "location", status: status.location)
                                StatusItemView(icon: "phone.connection", status: status.srtla)
                                StatusItemView(icon: "record.circle", status: status.recording)
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
                                        .bitrate > 0 ? formatBytesPerSecond(speed: Int64(preset.bitrate)) :
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
                            NavigationLink(destination: DebugLogSettingsView(
                                log: model.remoteControlAssistantLog,
                                formatLog: { model.formatLog(log: model.remoteControlAssistantLog) },
                                clearLog: { model.clearRemoteControlAssistantLog() },
                                quickDone: done
                            )) {
                                Text("Log")
                            }
                        } else {
                            Text("No settings received yet.")
                        }
                    } header: {
                        Text("Control")
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

private func startStopText(button: ButtonState) -> String {
    return button.isOn ? "Stop" : "Start"
}

struct ButtonsInnerView: View {
    @EnvironmentObject var model: Model
    var state: ButtonState
    var size: CGFloat
    var nameSize: CGFloat
    @State private var isPresentingRecordConfirm: Bool = false

    private func torchAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleTorch()
        model.updateButtonStates()
    }

    private func muteAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleMute()
        model.updateButtonStates()
    }

    private func widgetAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.sceneUpdated(store: false)
    }

    private func chatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showChatMessages.toggle()
        model.sceneUpdated(store: false)
    }

    private func interactiveChatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleInteractiveChat()
        model.sceneUpdated(store: false)
    }

    private func blackScreenAction(state _: ButtonState) {
        model.toggleBlackScreen()
        model.makeToast(
            title: String(localized: "Black screen"),
            subTitle: String(localized: "Double tap to return to main view")
        )
        model.updateButtonStates()
    }

    private func recordAction(state _: ButtonState) {
        if !model.isRecording {
            model.startRecording()
        } else {
            model.stopRecording()
        }
        model.updateButtonStates()
    }

    private func movieAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .movie, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
    }

    private func grayScaleAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .grayScale, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
    }

    private func sepiaAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .sepia, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
    }

    private func randomAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .random, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
    }

    private func tripleAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .triple, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
    }

    private func pixellateAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .pixellate, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
    }

    private func streamAction(state _: ButtonState) {
        model.showingStreamSwitcher = true
    }

    private func gridAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showingGrid.toggle()
        model.sceneUpdated(store: false)
    }

    private func obsAction(state _: ButtonState) {
        guard model.isObsRemoteControlConfigured() else {
            model.makeErrorToast(
                title: String(localized: "OBS remote control is not configured"),
                subTitle: String(
                    localized: """
                    Configure it in Settings → Streams → \(model.stream.name) → \
                    OBS remote control.
                    """
                )
            )
            return
        }
        model.showingObs = true
        model.listObsScenes()
        model.startObsSourceScreenshot()
        model.startObsAudioVolume()
        model.updateObsAudioDelay()
    }

    private func remoteAction(state _: ButtonState) {
        guard model.isRemoteControlAssistantConfigured() else {
            model.makeErrorToast(
                title: String(localized: "Remote control assistant is not configured"),
                subTitle: String(localized: "Configure it in Settings → Remote control")
            )
            return
        }
        model.showingRemoteControl = true
        model.updateRemoteControlAssistantStatus()
    }

    private func drawAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .draw, isOn: state.button.isOn)
        model.updateButtonStates()
        model.toggleDrawOnStream()
    }

    var body: some View {
        VStack {
            switch state.button.type {
            case .torch:
                Button(action: {
                    torchAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .mute:
                Button(action: {
                    muteAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .bitrate:
                Button(action: {
                    model.showingBitrate = true
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .widget:
                Button(action: {
                    widgetAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .mic:
                Button(action: {
                    model.showingMic = true
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .chat:
                Button(action: {
                    chatAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size, slash: true)
                })
            case .pauseChat:
                Button(action: {
                    interactiveChatAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .blackScreen:
                Button(action: {
                    blackScreenAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .obsScene:
                ButtonPlaceholderImage()
            case .obsStartStopStream:
                ButtonPlaceholderImage()
            case .record:
                Button(action: {
                    if model.database.startStopRecordingConfirmations! {
                        isPresentingRecordConfirm = true
                    } else {
                        recordAction(state: state)
                    }
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
                .confirmationDialog("", isPresented: $isPresentingRecordConfirm) {
                    Button(startStopText(button: state)) {
                        recordAction(state: state)
                    }
                }
            case .recordings:
                Button(action: {
                    model.showingRecordings = true
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .image:
                Button(action: {
                    model.showingCamera = true
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .movie:
                Button(action: {
                    movieAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .grayScale:
                Button(action: {
                    grayScaleAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .sepia:
                Button(action: {
                    sepiaAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .random:
                Button(action: {
                    randomAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .triple:
                Button(action: {
                    tripleAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .pixellate:
                Button(action: {
                    pixellateAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .stream:
                Button(action: {
                    streamAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .grid:
                Button(action: {
                    gridAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .obs:
                Button(action: {
                    obsAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .remote:
                Button(action: {
                    remoteAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .draw:
                Button(action: {
                    drawAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            }
            if model.database.quickButtons!.showName {
                Text(state.button.name)
                    .foregroundColor(.white)
                    .font(.system(size: nameSize))
            }
        }
    }
}

struct ButtonsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack {
            ForEach(model.buttonPairs) { pair in
                if model.database.quickButtons!.twoColumns {
                    HStack(alignment: .top) {
                        if let second = pair.second {
                            ButtonsInnerView(state: second, size: buttonSize, nameSize: 10)
                        } else {
                            ButtonPlaceholderImage()
                        }
                        ButtonsInnerView(state: pair.first, size: buttonSize, nameSize: 10)
                    }
                    .id(pair.first.button.id)
                } else {
                    if let second = pair.second {
                        ButtonsInnerView(state: second, size: singleButtonSize, nameSize: 12)
                    } else {
                        EmptyView()
                    }
                    ButtonsInnerView(state: pair.first, size: singleButtonSize, nameSize: 12)
                        .id(pair.first.button.id)
                }
            }
        }
    }
}
