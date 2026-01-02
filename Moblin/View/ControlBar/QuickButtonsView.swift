import AVFoundation
import SwiftUI

let controlBarPages = 5

private struct QuickButtonImage: View {
    let model: Model
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    let state: ButtonState
    let buttonSize: CGFloat
    let onTapGesture: () -> Void

    private func getImage(state: ButtonState) -> String {
        if state.isOn {
            return state.button.imageOn
        } else {
            return state.button.imageOff
        }
    }

    private var backgroundColor: Color {
        state.button.backgroundColor.color()
    }

    private func iconSize() -> Font {
        if quickButtonsSettings.bigButtons {
            return .system(size: 20)
        } else {
            return .body
        }
    }

    var body: some View {
        let image = Image(systemName: getImage(state: state))
            .font(iconSize())
            .frame(width: buttonSize, height: buttonSize)
            .foregroundStyle(.white)
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
        }
        .onTapGesture {
            onTapGesture()
        }
        .onLongPressGesture {
            model.showQuickButtonSettings(type: state.button.type)
        }
    }
}

private struct InstantReplayView: View {
    let model: Model
    @ObservedObject var replay: ReplayProvider
    let state: ButtonState
    let size: CGFloat

    var body: some View {
        if replay.isPlaying {
            Text(String(replay.timeLeft))
                .font(.system(size: 25))
                .frame(width: size, height: size)
                .foregroundStyle(.white)
                .background(state.button.backgroundColor.color())
                .clipShape(Circle())
                .onTapGesture {
                    if model.stream.replay.enabled {
                        model.instantReplay()
                    } else {
                        model.makeReplayIsNotEnabledToast()
                    }
                }
                .onLongPressGesture {
                    model.showQuickButtonSettings(type: .instantReplay)
                }
        } else {
            QuickButtonImage(model: model,
                             quickButtonsSettings: model.database.quickButtonsGeneral,
                             state: state,
                             buttonSize: size)
            {
                if model.stream.replay.enabled {
                    model.instantReplay()
                } else {
                    model.makeReplayIsNotEnabledToast()
                }
            }
        }
    }
}

struct QuickButtonPlaceholderImage: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "pawprint")
            .frame(width: size, height: size)
            .foregroundStyle(.black)
            .opacity(0.0)
            .padding(0)
    }
}

private struct ButtonTextOverlayView: View {
    let text: String

    var body: some View {
        Text(text)
            .rotationEffect(.degrees(-90))
            .offset(CGSize(width: 10, height: 0))
            .font(.system(size: 8))
            .foregroundStyle(.white)
            .frame(width: controlBarButtonSize, height: controlBarButtonSize)
    }
}

struct QuickButtonsInnerView: View {
    @EnvironmentObject var model: Model
    // periphery:ignore
    @ObservedObject var quickButtons: QuickButtons
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    @ObservedObject var orientation: Orientation
    let state: ButtonState
    let size: CGFloat
    let nameSize: CGFloat
    let nameWidth: CGFloat
    @State private var presentingRecordConfirm = false
    @State private var presentingStartWorkoutTypePicker = false
    @State private var presentingStopWorkoutConfirm = false

    private func torchAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleTorch()
        model.updateQuickButtonStates()
    }

    private func muteAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleMute()
        model.updateQuickButtonStates()
    }

    private func widgetAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.sceneUpdated()
    }

    private func stealthModeAction() {
        model.toggleStealthMode()
        model.updateQuickButtonStates()
    }

    private func lockScreenAction() {
        model.toggleLockScreen()
    }

    private func imageAction() {
        model.streamOverlay.showingCamera.toggle()
        model.updateImageButtonState()
    }

    private func recordAction() {
        if !model.isRecording {
            model.startRecording()
        } else {
            model.stopRecording()
        }
    }

    private func movieAction() {
        model.toggleFilterQuickButton(type: .movie)
    }

    private func whirlpoolAction() {
        model.toggleWhirlpoolQuickButton()
    }

    private func pinchAction() {
        model.togglePinchQuickButton()
    }

    private func fourThreeAction() {
        model.toggleFilterQuickButton(type: .fourThree)
    }

    private func grayScaleAction() {
        model.toggleFilterQuickButton(type: .grayScale)
    }

    private func sepiaAction() {
        model.toggleFilterQuickButton(type: .sepia)
    }

    private func tripleAction() {
        model.toggleFilterQuickButton(type: .triple)
    }

    private func twinAction() {
        model.toggleFilterQuickButton(type: .twin)
    }

    private func pixellateAction() {
        model.togglePixellateQuickButton()
    }

    private func pollAction() {
        model.togglePollQuickButton()
    }

    private func streamAction() {
        model.toggleShowingPanel(type: .stream, panel: .streamSwitcher)
    }

    private func gridAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showingGrid.toggle()
        model.sceneUpdated(updateRemoteScene: false)
        model.updateQuickButtonStates()
    }

    private func levelAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showingCameraLevel.toggle()
        model.reloadCameraLevel()
        model.sceneUpdated(updateRemoteScene: false)
        model.updateQuickButtonStates()
    }

    private func obsAction() {
        model.toggleShowingPanel(type: .obs, panel: .obs)
    }

    private func remoteAction() {
        model.showingRemoteControl.toggle()
        model.setQuickButtonState(type: .remote, isOn: model.showingRemoteControl)
        model.updateQuickButtonStates()
    }

    private func drawAction() {
        model.toggleDrawOnStream()
    }

    private func localOverlaysAction() {
        state.button.isOn.toggle()
        model.setQuickButtonState(type: .localOverlays, isOn: state.button.isOn)
        model.updateQuickButtonStates()
        model.toggleLocalOverlays()
    }

    private func browserAction() {
        state.button.isOn.toggle()
        model.setQuickButtonState(type: .browser, isOn: state.button.isOn)
        model.updateQuickButtonStates()
        model.toggleBrowser()
    }

    private func navigationAction() {
        state.button.isOn.toggle()
        model.setQuickButtonState(type: .navigation, isOn: state.button.isOn)
        model.updateQuickButtonStates()
        model.toggleNavigation()
    }

    private func cameraPreviewAction() {
        state.button.isOn.toggle()
        model.updateQuickButtonStates()
        model.reattachCamera()
    }

    private func snapshotAction() {
        model.takeSnapshot()
    }

    private func widgetsAction() {
        model.toggleShowingPanel(type: .widgets, panel: .widgets)
    }

    private func lutsAction() {
        model.toggleShowingPanel(type: .luts, panel: .luts)
        model.updateLutsButtonState()
    }

    private func chatAction() {
        model.toggleShowingPanel(type: .chat, panel: .chat)
    }

    private func interactiveChatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setQuickButtonState(type: .interactiveChat, isOn: state.button.isOn)
        model.updateQuickButtonStates()
        model.chat.interactiveChat = state.button.isOn
        if !state.button.isOn {
            model.disableInteractiveChat()
        }
    }

    private func micAction() {
        model.toggleShowingPanel(type: .mic, panel: .mic)
    }

    private func bitrateAction() {
        model.toggleShowingPanel(type: .bitrate, panel: .bitrate)
    }

    private func recordingsAction() {
        model.toggleShowingPanel(type: .recordings, panel: .recordings)
    }

    private func skipCurrentTtsAction() {
        model.chatTextToSpeech.skipCurrentMessage()
    }

    private func pauseTtsAction() {
        model.toggleTextToSpeechPaused()
    }

    private func streamMarkerAction() {
        model.createStreamMarker()
    }

    private func reloadBrowserWidgetsAction() {
        model.reloadBrowserWidgets()
    }

    private func djiDevicesAction() {
        model.toggleShowingPanel(type: .djiDevices, panel: .djiDevices)
    }

    private func portraitAction() {
        model.setDisplayPortrait(portrait: !model.database.portrait)
        model.reattachCamera()
    }

    private func goProAction() {
        model.toggleShowingPanel(type: .goPro, panel: .goPro)
    }

    private func replayAction(state: ButtonState) {
        model.streamOverlay.showingReplay.toggle()
        state.button.isOn.toggle()
        model.setQuickButtonState(type: .replay, isOn: state.button.isOn)
        model.updateQuickButtonStates()
    }

    private func liveAction() {
        model.toggleShowingPanel(type: .live, panel: .live)
    }

    private func connectionPrioritiesAction() {
        model.toggleShowingPanel(type: .connectionPriorities, panel: .connectionPriorities)
    }

    private func autoSceneSwitcherAction() {
        model.toggleShowingPanel(type: .autoSceneSwitcher, panel: .autoSceneSwitcher)
        model.updateAutoSceneSwitcherButtonState()
    }

    private func blurFacesAction() {
        model.toggleBlurFaces()
    }

    private func privacyAction() {
        model.togglePrivacy()
    }

    private func moblinInMouthAction() {
        model.toggleMoblinInMouth()
    }

    private func glassesAction() {
        model.triggerGlasses()
    }

    private func starAction() {
        model.triggerSparkle()
    }

    var body: some View {
        VStack(spacing: 0) {
            switch state.button.type {
            case .unknown:
                QuickButtonPlaceholderImage(size: size)
            case .torch:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    torchAction(state: state)
                }
            case .mute:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    muteAction(state: state)
                }
            case .bitrate:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    bitrateAction()
                }
            case .widget:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    widgetAction(state: state)
                }
            case .mic:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    micAction()
                }
            case .chat:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    chatAction()
                }
            case .interactiveChat:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    interactiveChatAction(state: state)
                }
            case .blackScreen:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    stealthModeAction()
                }
            case .lockScreen:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    lockScreenAction()
                }
            case .record:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    if model.database.startStopRecordingConfirmations {
                        presentingRecordConfirm = true
                    } else {
                        recordAction()
                    }
                }
                .confirmationDialog("", isPresented: $presentingRecordConfirm) {
                    Button(state.isOn ? "Stop recording" : "Start recording") {
                        recordAction()
                    }
                }
            case .recordings:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    recordingsAction()
                }
            case .image:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    imageAction()
                }
            case .movie:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    movieAction()
                }
            case .fourThree:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    fourThreeAction()
                }
            case .grayScale:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    grayScaleAction()
                }
            case .sepia:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    sepiaAction()
                }
            case .triple:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    tripleAction()
                }
            case .twin:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    twinAction()
                }
            case .pixellate:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    pixellateAction()
                }
            case .stream:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    streamAction()
                }
            case .grid:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    gridAction(state: state)
                }
            case .cameraLevel:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    levelAction(state: state)
                }
            case .obs:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    obsAction()
                }
            case .remote:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    remoteAction()
                }
            case .draw:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    drawAction()
                }
            case .localOverlays:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    localOverlaysAction()
                }
            case .browser:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    browserAction()
                }
            case .lut:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size) {}
            case .cameraPreview:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    cameraPreviewAction()
                }
            case .poll:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    pollAction()
                }
            case .snapshot:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    snapshotAction()
                }
            case .widgets:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    widgetsAction()
                }
            case .luts:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    lutsAction()
                }
            case .workout:
                if state.isOn {
                    QuickButtonImage(model: model,
                                     quickButtonsSettings: quickButtonsSettings,
                                     state: state,
                                     buttonSize: size)
                    {
                        presentingStopWorkoutConfirm = true
                    }
                    .confirmationDialog("", isPresented: $presentingStopWorkoutConfirm) {
                        Button("End workout") {
                            model.stopWorkout()
                        }
                    }
                } else {
                    QuickButtonImage(model: model,
                                     quickButtonsSettings: quickButtonsSettings,
                                     state: state,
                                     buttonSize: size)
                    {
                        presentingStartWorkoutTypePicker = true
                    }
                    .confirmationDialog("", isPresented: $presentingStartWorkoutTypePicker) {
                        Button("Start walking workout") {
                            model.startWorkout(type: .walking)
                        }
                        Button("Start running workout") {
                            model.startWorkout(type: .running)
                        }
                        Button("Start cycling workout") {
                            model.startWorkout(type: .cycling)
                        }
                    }
                }
            case .moderation:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    model.presentingModeration = true
                }
            case .predefinedMessages:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    model.showingPredefinedMessages = true
                }
            case .skipCurrentTts:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    skipCurrentTtsAction()
                }
            case .streamMarker:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    streamMarkerAction()
                }
            case .reloadBrowserWidgets:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    reloadBrowserWidgetsAction()
                }
            case .djiDevices:
                ZStack {
                    QuickButtonImage(model: model,
                                     quickButtonsSettings: quickButtonsSettings,
                                     state: state,
                                     buttonSize: size)
                    {
                        djiDevicesAction()
                    }
                    ButtonTextOverlayView(text: String(localized: "DJI"))
                }
            case .portrait:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    portraitAction()
                }
            case .goPro:
                ZStack {
                    QuickButtonImage(model: model,
                                     quickButtonsSettings: quickButtonsSettings,
                                     state: state,
                                     buttonSize: size)
                    {
                        goProAction()
                    }
                    ButtonTextOverlayView(text: String(localized: "GoPro"))
                }
            case .replay:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    replayAction(state: state)
                }
            case .instantReplay:
                InstantReplayView(model: model, replay: model.replay, state: state, size: size)
            case .connectionPriorities:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    connectionPrioritiesAction()
                }
            case .whirlpool:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    whirlpoolAction()
                }
            case .pinch:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    pinchAction()
                }
            case .autoSceneSwitcher:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    autoSceneSwitcherAction()
                }
            case .pauseTts:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    pauseTtsAction()
                }
            case .live:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    liveAction()
                }
            case .navigation:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    navigationAction()
                }
            case .blurFaces:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    blurFacesAction()
                }
            case .moblinInMouth:
                ZStack {
                    QuickButtonImage(model: model,
                                     quickButtonsSettings: quickButtonsSettings,
                                     state: state,
                                     buttonSize: size)
                    {
                        moblinInMouthAction()
                    }
                    Image("MoblinInMouth")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 21, height: 40)
                        .offset(.init(width: 0, height: 3))
                }
            case .privacy:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    privacyAction()
                }
            case .glasses:
                QuickButtonImage(model: model,
                                 quickButtonsSettings: quickButtonsSettings,
                                 state: state,
                                 buttonSize: size)
                {
                    glassesAction()
                }
            case .sparkle:
                ZStack {
                    QuickButtonImage(model: model,
                                     quickButtonsSettings: quickButtonsSettings,
                                     state: state,
                                     buttonSize: size)
                    {
                        starAction()
                    }
                    Image(systemName: "sparkle")
                        .rotationEffect(.degrees(70))
                        .offset(CGSize(width: 11, height: 0))
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: size, height: size)
                }
            }
            if quickButtonsSettings.showName && !orientation.isPortrait {
                Text(state.button.name)
                    .padding(0)
                    .multilineTextAlignment(.center)
                    .frame(width: nameWidth, alignment: .center)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .font(.system(size: nameSize))
            }
        }
        .rotationEffect(.degrees(180))
    }
}
