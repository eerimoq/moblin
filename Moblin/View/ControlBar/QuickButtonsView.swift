import AVFoundation
import SwiftUI

let controlBarPages = 5

private struct QuickButtonImage: View {
    @EnvironmentObject var model: Model
    var state: ButtonState
    var buttonSize: CGFloat
    var onTapGesture: () -> Void

    private func getImage(state: ButtonState) -> String {
        if state.isOn {
            return state.button.systemImageNameOn
        } else {
            return state.button.systemImageNameOff
        }
    }

    private var backgroundColor: Color {
        state.button.backgroundColor.color()
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
        }.onTapGesture {
            onTapGesture()
        }
        .onLongPressGesture {
            model.showQuickButtonSettings(type: state.button.type)
        }
    }
}

private struct InstantReplayView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var replay: ReplayProvider
    var state: ButtonState
    var size: CGFloat

    var body: some View {
        if replay.isPlaying {
            Text(String(replay.timeLeft))
                .font(.system(size: 25))
                .frame(width: size, height: size)
                .foregroundColor(.white)
                .background(state.button.backgroundColor.color())
                .clipShape(Circle())
                .onTapGesture {
                    if model.stream.replay!.enabled {
                        model.instantReplay()
                    } else {
                        model.makeReplayIsNotEnabledToast()
                    }
                }
                .onLongPressGesture {
                    model.showQuickButtonSettings(type: .instantReplay)
                }
        } else {
            QuickButtonImage(state: state, buttonSize: size) {
                if model.stream.replay!.enabled {
                    model.instantReplay()
                } else {
                    model.makeReplayIsNotEnabledToast()
                }
            }
        }
    }
}

struct QuickButtonPlaceholderImage: View {
    var body: some View {
        Image(systemName: "pawprint")
            .frame(width: controlBarButtonSize, height: controlBarButtonSize)
            .foregroundColor(.black)
            .opacity(0.0)
    }
}

private func startStopText(button: ButtonState) -> String {
    if button.isOn {
        return String(localized: "Stop")
    } else {
        return String(localized: "Start")
    }
}

private struct ButtonTextOverlayView: View {
    let text: String

    var body: some View {
        Text(text)
            .rotationEffect(.degrees(-90))
            .offset(CGSize(width: 10, height: 0))
            .font(.system(size: 8))
            .foregroundColor(.white)
            .frame(width: controlBarButtonSize, height: controlBarButtonSize)
    }
}

struct QuickButtonsInnerView: View {
    @EnvironmentObject var model: Model
    var state: ButtonState
    var size: CGFloat
    var nameSize: CGFloat
    var nameWidth: CGFloat
    @State private var isPresentingRecordConfirm = false
    @State private var isPresentingStartWorkoutTypePicker = false
    @State private var isPresentingAdsTimePicker = false
    @State private var isPresentingStopWorkoutConfirm = false

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

    private func blackScreenAction() {
        model.toggleBlackScreen()
        model.makeToast(
            title: String(localized: "Black screen"),
            subTitle: String(localized: "Double tap to return to main view")
        )
        model.updateQuickButtonStates()
    }

    private func lockScreenAction() {
        model.toggleLockScreen()
    }

    private func imageAction() {
        model.showingCamera.toggle()
        model.updateImageButtonState()
    }

    private func recordAction() {
        if !model.isRecording {
            model.startRecording()
        } else {
            model.stopRecording()
        }
    }

    private func videoEffectAction(state: ButtonState, type: SettingsQuickButtonType) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: type, isOn: state.button.isOn)
        model.sceneUpdated(updateRemoteScene: false)
        model.updateQuickButtonStates()
    }

    private func movieAction(state: ButtonState) {
        videoEffectAction(state: state, type: .movie)
    }

    private func whirlpoolAction(state: ButtonState) {
        videoEffectAction(state: state, type: .whirlpool)
    }

    private func pinchAction(state: ButtonState) {
        videoEffectAction(state: state, type: .pinch)
    }

    private func fourThreeAction(state: ButtonState) {
        videoEffectAction(state: state, type: .fourThree)
    }

    private func grayScaleAction(state: ButtonState) {
        videoEffectAction(state: state, type: .grayScale)
    }

    private func sepiaAction(state: ButtonState) {
        videoEffectAction(state: state, type: .sepia)
    }

    private func tripleAction(state: ButtonState) {
        videoEffectAction(state: state, type: .triple)
    }

    private func twinAction(state: ButtonState) {
        videoEffectAction(state: state, type: .twin)
    }

    private func pixellateAction(state: ButtonState) {
        videoEffectAction(state: state, type: .pixellate)
        model.showingPixellate.toggle()
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

    private func obsAction() {
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
        model.toggleShowingPanel(type: .obs, panel: .obs)
    }

    private func remoteAction() {
        guard model.isRemoteControlAssistantConfigured() else {
            model.makeErrorToast(
                title: String(localized: "Remote control assistant is not configured"),
                subTitle: String(localized: "Configure it in Settings → Remote control")
            )
            return
        }
        model.showingRemoteControl.toggle()
        model.setGlobalButtonState(type: .remote, isOn: model.showingRemoteControl)
        model.updateQuickButtonStates()
    }

    private func drawAction() {
        model.toggleDrawOnStream()
    }

    private func localOverlaysAction() {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .localOverlays, isOn: state.button.isOn)
        model.updateQuickButtonStates()
        model.toggleLocalOverlays()
    }

    private func browserAction() {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .browser, isOn: state.button.isOn)
        model.updateQuickButtonStates()
        model.toggleBrowser()
    }

    private func cameraPreviewAction() {
        state.button.isOn.toggle()
        model.updateQuickButtonStates()
        model.reattachCamera()
    }

    private func faceAction() {
        model.showFace.toggle()
        model.updateFaceFilterButtonState()
    }

    private func pollAction() {
        model.togglePoll()
        videoEffectAction(state: state, type: .poll)
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
        model.setGlobalButtonState(type: .interactiveChat, isOn: state.button.isOn)
        model.updateQuickButtonStates()
        model.interactiveChat = state.button.isOn
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
    }

    private func goProAction() {
        model.toggleShowingPanel(type: .goPro, panel: .goPro)
    }

    private func replayAction(state: ButtonState) {
        model.showingReplay.toggle()
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .replay, isOn: state.button.isOn)
        model.updateQuickButtonStates()
    }

    private func connectionPrioritiesAction() {
        model.toggleShowingPanel(type: .connectionPriorities, panel: .connectionPriorities)
    }

    private func autoSceneSwitcherAction() {
        model.toggleShowingPanel(type: .autoSceneSwitcher, panel: .autoSceneSwitcher)
        model.updateAutoSceneSwitcherButtonState()
    }

    var body: some View {
        VStack {
            switch state.button.type {
            case .unknown:
                QuickButtonPlaceholderImage()
            case .torch:
                QuickButtonImage(state: state, buttonSize: size) {
                    torchAction(state: state)
                }
            case .mute:
                QuickButtonImage(state: state, buttonSize: size) {
                    muteAction(state: state)
                }
            case .bitrate:
                QuickButtonImage(state: state, buttonSize: size) {
                    bitrateAction()
                }
            case .widget:
                QuickButtonImage(state: state, buttonSize: size) {
                    widgetAction(state: state)
                }
            case .mic:
                QuickButtonImage(state: state, buttonSize: size) {
                    micAction()
                }
            case .chat:
                QuickButtonImage(state: state, buttonSize: size) {
                    chatAction()
                }
            case .interactiveChat:
                QuickButtonImage(state: state, buttonSize: size) {
                    interactiveChatAction(state: state)
                }
            case .blackScreen:
                QuickButtonImage(state: state, buttonSize: size) {
                    blackScreenAction()
                }
            case .lockScreen:
                QuickButtonImage(state: state, buttonSize: size) {
                    lockScreenAction()
                }
            case .record:
                QuickButtonImage(state: state, buttonSize: size) {
                    if model.database.startStopRecordingConfirmations {
                        isPresentingRecordConfirm = true
                    } else {
                        recordAction()
                    }
                }
                .confirmationDialog("", isPresented: $isPresentingRecordConfirm) {
                    Button(startStopText(button: state)) {
                        recordAction()
                    }
                }
            case .recordings:
                QuickButtonImage(state: state, buttonSize: size) {
                    recordingsAction()
                }
            case .image:
                QuickButtonImage(state: state, buttonSize: size) {
                    imageAction()
                }
            case .movie:
                QuickButtonImage(state: state, buttonSize: size) {
                    movieAction(state: state)
                }
            case .fourThree:
                QuickButtonImage(state: state, buttonSize: size) {
                    fourThreeAction(state: state)
                }
            case .grayScale:
                QuickButtonImage(state: state, buttonSize: size) {
                    grayScaleAction(state: state)
                }
            case .sepia:
                QuickButtonImage(state: state, buttonSize: size) {
                    sepiaAction(state: state)
                }
            case .triple:
                QuickButtonImage(state: state, buttonSize: size) {
                    tripleAction(state: state)
                }
            case .twin:
                QuickButtonImage(state: state, buttonSize: size) {
                    twinAction(state: state)
                }
            case .pixellate:
                QuickButtonImage(state: state, buttonSize: size) {
                    pixellateAction(state: state)
                }
            case .stream:
                QuickButtonImage(state: state, buttonSize: size) {
                    streamAction()
                }
            case .grid:
                QuickButtonImage(state: state, buttonSize: size) {
                    gridAction(state: state)
                }
            case .obs:
                QuickButtonImage(state: state, buttonSize: size) {
                    obsAction()
                }
            case .remote:
                QuickButtonImage(state: state, buttonSize: size) {
                    remoteAction()
                }
            case .draw:
                QuickButtonImage(state: state, buttonSize: size) {
                    drawAction()
                }
            case .localOverlays:
                QuickButtonImage(state: state, buttonSize: size) {
                    localOverlaysAction()
                }
            case .browser:
                QuickButtonImage(state: state, buttonSize: size) {
                    browserAction()
                }
            case .lut:
                QuickButtonImage(state: state, buttonSize: size) {}
            case .cameraPreview:
                QuickButtonImage(state: state, buttonSize: size) {
                    cameraPreviewAction()
                }
            case .face:
                QuickButtonImage(state: state, buttonSize: size) {
                    faceAction()
                }
            case .poll:
                QuickButtonImage(state: state, buttonSize: size) {
                    pollAction()
                }
            case .snapshot:
                QuickButtonImage(state: state, buttonSize: size) {
                    snapshotAction()
                }
            case .widgets:
                QuickButtonImage(state: state, buttonSize: size) {
                    widgetsAction()
                }
            case .luts:
                QuickButtonImage(state: state, buttonSize: size) {
                    lutsAction()
                }
            case .workout:
                if state.isOn {
                    QuickButtonImage(state: state, buttonSize: size) {
                        isPresentingStopWorkoutConfirm = true
                    }
                    .confirmationDialog("", isPresented: $isPresentingStopWorkoutConfirm) {
                        Button("End workout") {
                            model.stopWorkout()
                        }
                    }
                } else {
                    QuickButtonImage(state: state, buttonSize: size) {
                        isPresentingStartWorkoutTypePicker = true
                    }
                    .confirmationDialog("", isPresented: $isPresentingStartWorkoutTypePicker) {
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
            case .ads:
                QuickButtonImage(state: state, buttonSize: size) {
                    isPresentingAdsTimePicker = true
                }
                .confirmationDialog("", isPresented: $isPresentingAdsTimePicker) {
                    Button("30 seconds") {
                        model.startAds(seconds: 30)
                    }
                    Button("1 minute") {
                        model.startAds(seconds: 60)
                    }
                    Button("2 minutes") {
                        model.startAds(seconds: 120)
                    }
                    Button("3 minutes") {
                        model.startAds(seconds: 180)
                    }
                }
            case .skipCurrentTts:
                QuickButtonImage(state: state, buttonSize: size) {
                    skipCurrentTtsAction()
                }
            case .streamMarker:
                QuickButtonImage(state: state, buttonSize: size) {
                    streamMarkerAction()
                }
            case .reloadBrowserWidgets:
                QuickButtonImage(state: state, buttonSize: size) {
                    reloadBrowserWidgetsAction()
                }
            case .djiDevices:
                ZStack {
                    QuickButtonImage(state: state, buttonSize: size) {
                        djiDevicesAction()
                    }
                    ButtonTextOverlayView(text: String(localized: "DJI"))
                }
            case .portrait:
                QuickButtonImage(state: state, buttonSize: size) {
                    portraitAction()
                }
            case .goPro:
                ZStack {
                    QuickButtonImage(state: state, buttonSize: size) {
                        goProAction()
                    }
                    ButtonTextOverlayView(text: String(localized: "GoPro"))
                }
            case .replay:
                QuickButtonImage(state: state, buttonSize: size) {
                    replayAction(state: state)
                }
            case .instantReplay:
                InstantReplayView(replay: model.replay, state: state, size: size)
            case .connectionPriorities:
                QuickButtonImage(state: state, buttonSize: size) {
                    connectionPrioritiesAction()
                }
            case .whirlpool:
                QuickButtonImage(state: state, buttonSize: size) {
                    whirlpoolAction(state: state)
                }
            case .pinch:
                QuickButtonImage(state: state, buttonSize: size) {
                    pinchAction(state: state)
                }
            case .autoSceneSwitcher:
                QuickButtonImage(state: state, buttonSize: size) {
                    autoSceneSwitcherAction()
                }
            case .pauseTts:
                QuickButtonImage(state: state, buttonSize: size) {
                    pauseTtsAction()
                }
            }
            if model.database.quickButtonsGeneral.showName && !model.isPortrait() {
                Text(state.button.name)
                    .multilineTextAlignment(.center)
                    .frame(width: nameWidth, alignment: .center)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .font(.system(size: nameSize))
            }
        }
        .rotationEffect(.degrees(180))
    }
}
