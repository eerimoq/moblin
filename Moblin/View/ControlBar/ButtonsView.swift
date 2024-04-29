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
                        .frame(width: buttonSize - 1, height: buttonSize - 1)
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
                        model.setIsLive(value: true)
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
            Section {
                Toggle(isOn: Binding(get: {
                    model.getIsManualFocusEnabled()
                }, set: { value in
                    if value {
                        model.setManualFocus(lensPosition: model.manualFocus)
                    } else {
                        model.setAutoFocus()
                    }
                }), label: {
                    Slider(
                        value: $model.manualFocus,
                        in: 0 ... 1,
                        step: 0.01,
                        onEditingChanged: { begin in
                            model.editingManualFocus = begin
                            guard !begin else {
                                return
                            }
                            model.setManualFocus(lensPosition: model.manualFocus)
                        }
                    )
                    .onChange(of: model.manualFocus) { _ in
                        if model.editingManualFocus {
                            model.setManualFocus(lensPosition: model.manualFocus)
                        }
                    }
                })
                .disabled(!model.isCameraSupportingManualFocus())
            } header: {
                Text("Manual focus")
            } footer: {
                if !model.isCameraSupportingManualFocus() {
                    Text("Manual focus not supported for this camera. Use a non-triple/dual camera.")
                }
            }
            Section {
                Toggle(isOn: Binding(get: {
                    model.getIsManualExposureEnabled()
                }, set: { value in
                    if value {
                        model.setManualExposure(exposure: model.manualExposure)
                    } else {
                        model.setAutoExposure()
                    }
                }), label: {
                    Slider(
                        value: $model.manualExposure,
                        in: 0 ... 1,
                        step: 0.01,
                        onEditingChanged: { begin in
                            model.editingManualExposure = begin
                            guard !begin else {
                                return
                            }
                            model.setManualExposure(exposure: model.manualExposure)
                        }
                    )
                    .onChange(of: model.manualExposure) { _ in
                        if model.editingManualExposure {
                            model.setManualExposure(exposure: model.manualExposure)
                        }
                    }
                })
                .disabled(!model.isCameraSupportingManualExposure())
            } header: {
                Text("Manual exposure")
            }
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
        .onAppear {
            model.startObservingFocus()
            model.startObservingExposure()
        }
        .onDisappear {
            model.stopObservingFocus()
            model.stopObservingExposure()
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
                    if !model.obsFixOngoing {
                        Section {
                            HStack {
                                Spacer()
                                Button(action: {
                                    model.obsFixStream()
                                }, label: {
                                    Text("Fix \(model.stream.obsSourceName!) source")
                                })
                                Spacer()
                            }
                        } footer: {
                            Text("""
                            Restarts the \(model.stream.obsSourceName!) source to hopefully fix \
                            audio and video issues.
                            """)
                        }
                        .listRowBackground(RoundedRectangle(cornerRadius: 10)
                            .foregroundColor(Color(uiColor: .secondarySystemGroupedBackground))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(.blue, lineWidth: 2)))
                    } else {
                        Section {
                            HStack {
                                Spacer()
                                Text("Fixing...")
                                Spacer()
                            }
                            .foregroundColor(.white)
                        } footer: {
                            Text("""
                            Restarts the \(model.stream.obsSourceName!) source to hopefully fix \
                            audio and video issues.
                            """)
                        }
                        .listRowBackground(Color.gray)
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

private func startStopText(button: ButtonState) -> String {
    return button.isOn ? "Stop" : "Start"
}

struct ButtonsInnerView: View {
    @EnvironmentObject var model: Model
    var state: ButtonState
    var size: CGFloat
    var nameSize: CGFloat
    var nameWidth: CGFloat
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
        model.updateButtonStates()
    }

    private func interactiveChatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleInteractiveChat()
        model.sceneUpdated(store: false)
        model.updateButtonStates()
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

    private func videoEffectAction(state: ButtonState, type: SettingsButtonType) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: type, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
        model.updateButtonStates()
    }

    private func movieAction(state: ButtonState) {
        videoEffectAction(state: state, type: .movie)
    }

    private func grayScaleAction(state: ButtonState) {
        videoEffectAction(state: state, type: .grayScale)
    }

    private func sepiaAction(state: ButtonState) {
        videoEffectAction(state: state, type: .sepia)
    }

    private func randomAction(state: ButtonState) {
        videoEffectAction(state: state, type: .random)
    }

    private func tripleAction(state: ButtonState) {
        videoEffectAction(state: state, type: .triple)
    }

    private func pixellateAction(state: ButtonState) {
        videoEffectAction(state: state, type: .pixellate)
    }

    private func streamAction(state _: ButtonState) {
        model.showingStreamSwitcher = true
    }

    private func gridAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showingGrid.toggle()
        model.sceneUpdated(store: false)
        model.updateButtonStates()
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
        model.detachCamera()
        model.updateScreenAutoOff()
    }

    private func drawAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .draw, isOn: state.button.isOn)
        model.updateButtonStates()
        model.toggleDrawOnStream()
    }

    private func localOverlaysAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .localOverlays, isOn: state.button.isOn)
        model.updateButtonStates()
        model.toggleLocalOverlays()
    }

    private func browserAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .browser, isOn: state.button.isOn)
        model.updateButtonStates()
        model.toggleBrowser()
    }

    private func lutAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.updateButtonStates()
        model.sceneUpdated(store: false)
    }

    private func cameraPreviewAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.updateButtonStates()
        model.showCameraPreview.toggle()
    }

    var body: some View {
        VStack {
            switch state.button.type {
            case .unknown:
                ButtonPlaceholderImage()
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
            case .interactiveChat:
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
            case .localOverlays:
                Button(action: {
                    localOverlaysAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .browser:
                Button(action: {
                    browserAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .lut:
                Button(action: {
                    lutAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            case .cameraPreview:
                Button(action: {
                    cameraPreviewAction(state: state)
                }, label: {
                    ButtonImage(state: state, buttonSize: size)
                })
            }
            if model.database.quickButtons!.showName && !model.stream.portrait! {
                Text(state.button.name)
                    .multilineTextAlignment(.center)
                    .frame(width: nameWidth, alignment: .center)
                    .foregroundColor(.white)
                    .font(.system(size: nameSize))
            }
        }
    }
}

struct ButtonsLandscapeView: View {
    @EnvironmentObject var model: Model
    var width: CGFloat

    var body: some View {
        VStack {
            ForEach(model.buttonPairs) { pair in
                if model.database.quickButtons!.twoColumns {
                    HStack(alignment: .top) {
                        if let second = pair.second {
                            ButtonsInnerView(
                                state: second,
                                size: buttonSize,
                                nameSize: 10,
                                nameWidth: buttonSize
                            )
                        } else {
                            ButtonPlaceholderImage()
                        }
                        ButtonsInnerView(
                            state: pair.first,
                            size: buttonSize,
                            nameSize: 10,
                            nameWidth: buttonSize
                        )
                    }
                    .id(pair.first.button.id)
                } else {
                    if let second = pair.second {
                        ButtonsInnerView(
                            state: second,
                            size: singleButtonSize,
                            nameSize: 12,
                            nameWidth: width - 10
                        )
                    } else {
                        EmptyView()
                    }
                    ButtonsInnerView(
                        state: pair.first,
                        size: singleButtonSize,
                        nameSize: 12,
                        nameWidth: width - 10
                    )
                    .id(pair.first.button.id)
                }
            }
        }
    }
}

struct ButtonsPortraitView: View {
    @EnvironmentObject var model: Model
    var width: CGFloat

    var body: some View {
        HStack {
            ForEach(model.buttonPairs) { pair in
                if model.database.quickButtons!.twoColumns {
                    VStack(alignment: .leading) {
                        if let second = pair.second {
                            ButtonsInnerView(
                                state: second,
                                size: buttonSize,
                                nameSize: 10,
                                nameWidth: buttonSize
                            )
                        } else {
                            ButtonPlaceholderImage()
                        }
                        ButtonsInnerView(
                            state: pair.first,
                            size: buttonSize,
                            nameSize: 10,
                            nameWidth: buttonSize
                        )
                    }
                    .id(pair.first.button.id)
                } else {
                    if let second = pair.second {
                        ButtonsInnerView(
                            state: second,
                            size: singleButtonSize,
                            nameSize: 12,
                            nameWidth: width - 10
                        )
                    } else {
                        EmptyView()
                    }
                    ButtonsInnerView(
                        state: pair.first,
                        size: singleButtonSize,
                        nameSize: 12,
                        nameWidth: width - 10
                    )
                    .id(pair.first.button.id)
                }
            }
        }
    }
}
