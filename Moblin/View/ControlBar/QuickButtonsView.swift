import AVFoundation
import SwiftUI

let singleQuickButtonSize: CGFloat = 45

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
                .background(state.button.backgroundColor!.color())
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
        Button {} label: {
            Image(systemName: "pawprint")
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(.black)
        }
        .opacity(0.0)
    }
}

private func startStopText(button: ButtonState) -> String {
    return button.isOn ? String(localized: "Stop") : String(localized: "Start")
}

private struct ButtonTextOverlayView: View {
    let text: String

    var body: some View {
        Text(text)
            .rotationEffect(.degrees(-90))
            .offset(CGSize(width: 10, height: 0))
            .font(.system(size: 8))
            .foregroundColor(.white)
            .frame(width: buttonSize, height: buttonSize)
    }
}

struct QuickButtonsInnerView: View {
    @EnvironmentObject var model: Model
    var state: ButtonState
    var size: CGFloat
    var nameSize: CGFloat
    var nameWidth: CGFloat
    @State private var isPresentingRecordConfirm: Bool = false
    @State private var isPresentingStartWorkoutTypePicker: Bool = false
    @State private var isPresentingAdsTimePicker: Bool = false
    @State private var isPresentingStopWorkoutConfirm: Bool = false

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
        model.sceneUpdated()
    }

    private func blackScreenAction() {
        model.toggleBlackScreen()
        model.makeToast(
            title: String(localized: "Black screen"),
            subTitle: String(localized: "Double tap to return to main view")
        )
        model.updateButtonStates()
    }

    private func lockScreenAction() {
        model.toggleLockScreen()
    }

    private func imageAction(state _: ButtonState) {
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
        model.updateButtonStates()
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

    private func streamAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .stream, panel: .streamSwitcher)
    }

    private func gridAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showingGrid.toggle()
        model.sceneUpdated(updateRemoteScene: false)
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
        model.toggleShowingPanel(type: .obs, panel: .obs)
    }

    private func remoteAction(state _: ButtonState) {
        guard model.isRemoteControlAssistantConfigured() else {
            model.makeErrorToast(
                title: String(localized: "Remote control assistant is not configured"),
                subTitle: String(localized: "Configure it in Settings → Remote control")
            )
            return
        }
        model.showingRemoteControl.toggle()
        model.setGlobalButtonState(type: .remote, isOn: model.showingRemoteControl)
        model.updateButtonStates()
    }

    private func drawAction(state _: ButtonState) {
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

    private func cameraPreviewAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.updateButtonStates()
        model.reattachCamera()
    }

    private func faceAction(state _: ButtonState) {
        model.showFace.toggle()
        model.updateFaceFilterButtonState()
    }

    private func pollAction(state _: ButtonState) {
        model.togglePoll()
        videoEffectAction(state: state, type: .poll)
    }

    private func snapshotAction(state _: ButtonState) {
        model.takeSnapshot()
    }

    private func widgetsAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .widgets, panel: .widgets)
    }

    private func lutsAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .luts, panel: .luts)
        model.updateLutsButtonState()
    }

    private func chatAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .chat, panel: .chat)
    }

    private func interactiveChatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .interactiveChat, isOn: state.button.isOn)
        model.updateButtonStates()
        model.interactiveChat = state.button.isOn
        if !state.button.isOn {
            model.disableInteractiveChat()
        }
    }

    private func micAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .mic, panel: .mic)
    }

    private func bitrateAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .bitrate, panel: .bitrate)
    }

    private func recordingsAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .recordings, panel: .recordings)
    }

    private func skipCurrentTtsAction(state _: ButtonState) {
        model.chatTextToSpeech.skipCurrentMessage()
    }

    private func streamMarkerAction(state _: ButtonState) {
        model.createStreamMarker()
    }

    private func reloadBrowserWidgetsAction(state _: ButtonState) {
        model.reloadBrowserWidgets()
    }

    private func djiDevicesAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .djiDevices, panel: .djiDevices)
    }

    private func portraitAction(state _: ButtonState) {
        model.setDisplayPortrait(portrait: !model.database.portrait!)
    }

    private func goProAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .goPro, panel: .goPro)
    }

    private func replayAction(state: ButtonState) {
        model.showingReplay.toggle()
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .replay, isOn: state.button.isOn)
        model.updateButtonStates()
    }

    private func connectionPrioritiesAction(state _: ButtonState) {
        model.toggleShowingPanel(type: .connectionPriorities, panel: .connectionPriorities)
    }

    private func autoSceneSwitcherAction(state _: ButtonState) {
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
                    bitrateAction(state: state)
                }
            case .widget:
                QuickButtonImage(state: state, buttonSize: size) {
                    widgetAction(state: state)
                }
            case .mic:
                QuickButtonImage(state: state, buttonSize: size) {
                    micAction(state: state)
                }
            case .chat:
                QuickButtonImage(state: state, buttonSize: size) {
                    chatAction(state: state)
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
                    if model.database.startStopRecordingConfirmations! {
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
                    recordingsAction(state: state)
                }
            case .image:
                QuickButtonImage(state: state, buttonSize: size) {
                    imageAction(state: state)
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
                    streamAction(state: state)
                }
            case .grid:
                QuickButtonImage(state: state, buttonSize: size) {
                    gridAction(state: state)
                }
            case .obs:
                QuickButtonImage(state: state, buttonSize: size) {
                    obsAction(state: state)
                }
            case .remote:
                QuickButtonImage(state: state, buttonSize: size) {
                    remoteAction(state: state)
                }
            case .draw:
                QuickButtonImage(state: state, buttonSize: size) {
                    drawAction(state: state)
                }
            case .localOverlays:
                QuickButtonImage(state: state, buttonSize: size) {
                    localOverlaysAction(state: state)
                }
            case .browser:
                QuickButtonImage(state: state, buttonSize: size) {
                    browserAction(state: state)
                }
            case .lut:
                QuickButtonImage(state: state, buttonSize: size) {}
            case .cameraPreview:
                QuickButtonImage(state: state, buttonSize: size) {
                    cameraPreviewAction(state: state)
                }
            case .face:
                QuickButtonImage(state: state, buttonSize: size) {
                    faceAction(state: state)
                }
            case .poll:
                QuickButtonImage(state: state, buttonSize: size) {
                    pollAction(state: state)
                }
            case .snapshot:
                QuickButtonImage(state: state, buttonSize: size) {
                    snapshotAction(state: state)
                }
            case .widgets:
                QuickButtonImage(state: state, buttonSize: size) {
                    widgetsAction(state: state)
                }
            case .luts:
                QuickButtonImage(state: state, buttonSize: size) {
                    lutsAction(state: state)
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
                    skipCurrentTtsAction(state: state)
                }
            case .streamMarker:
                QuickButtonImage(state: state, buttonSize: size) {
                    streamMarkerAction(state: state)
                }
            case .reloadBrowserWidgets:
                QuickButtonImage(state: state, buttonSize: size) {
                    reloadBrowserWidgetsAction(state: state)
                }
            case .djiDevices:
                ZStack {
                    QuickButtonImage(state: state, buttonSize: size) {
                        djiDevicesAction(state: state)
                    }
                    ButtonTextOverlayView(text: String(localized: "DJI"))
                }
            case .portrait:
                QuickButtonImage(state: state, buttonSize: size) {
                    portraitAction(state: state)
                }
            case .goPro:
                ZStack {
                    QuickButtonImage(state: state, buttonSize: size) {
                        goProAction(state: state)
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
                    connectionPrioritiesAction(state: state)
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
                    autoSceneSwitcherAction(state: state)
                }
            }
            if model.database.quickButtons!.showName && !model.isPortrait() {
                Text(state.button.name)
                    .multilineTextAlignment(.center)
                    .frame(width: nameWidth, alignment: .center)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .font(.system(size: nameSize))
            }
        }
    }
}
