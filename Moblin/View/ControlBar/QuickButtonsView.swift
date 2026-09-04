import AVFoundation
import SwiftUI

let controlBarPages = 5

private struct QuickButtonImage: View {
    let model: Model
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    @ObservedObject var button: SettingsQuickButton
    let buttonSize: CGFloat
    var hideImage: Bool = false
    let onTapGesture: () -> Void

    private func getImage() -> String {
        if button.isOn {
            button.imageOn
        } else {
            button.imageOff
        }
    }

    private func foregroundColor() -> Color {
        if hideImage {
            .clear
        } else {
            .white
        }
    }

    private func backgroundColor() -> Color {
        button.backgroundColor.color()
    }

    private func iconSize() -> Font {
        if quickButtonsSettings.bigButtons {
            .system(size: 20)
        } else {
            .body
        }
    }

    var body: some View {
        let image = Image(systemName: getImage())
            .font(iconSize())
            .frame(width: buttonSize, height: buttonSize)
            .foregroundStyle(foregroundColor())
            .background(backgroundColor())
            .clipShape(Circle())
        ZStack {
            if button.isOn {
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
            model.showQuickButtonSettings(type: button.type)
        }
    }
}

private struct InstantReplayView: View {
    let model: Model
    @ObservedObject var replay: ReplayProvider
    @ObservedObject var button: SettingsQuickButton
    let size: CGFloat

    var body: some View {
        if replay.isPlaying {
            Text(String(replay.timeLeft))
                .font(.system(size: 25))
                .frame(width: size, height: size)
                .foregroundStyle(.white)
                .background(button.backgroundColor.color())
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
                             button: button,
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
    @ObservedObject var quickButtons: QuickButtons
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    @ObservedObject var orientation: Orientation
    @ObservedObject var button: SettingsQuickButton
    let size: CGFloat
    let nameSize: CGFloat
    let nameWidth: CGFloat
    @State private var presentingRecordConfirm = false
    @State private var presentingPreviewStreamConfirm = false
    @State private var presentingStartWorkoutTypePicker = false
    @State private var presentingStopWorkoutConfirm = false

    private func torchAction() {
        button.isOn.toggle()
        model.toggleTorch()
    }

    private func muteAction() {
        button.isOn.toggle()
        model.toggleMute()
    }

    private func stealthModeAction() {
        model.toggleStealthMode()
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

    private func crtAction() {
        model.toggleFilterQuickButton(type: .crt)
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

    private func cameraManAction() {
        model.toggleCameraManQuickButton()
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

    private func gridAction() {
        button.isOn.toggle()
        model.showingGrid.toggle()
        model.sceneUpdated(updateRemoteScene: false)
    }

    private func levelAction() {
        button.isOn.toggle()
        model.showingCameraLevel.toggle()
        model.reloadCameraLevel()
        model.sceneUpdated(updateRemoteScene: false)
    }

    private func obsAction() {
        model.toggleShowingPanel(type: .obs, panel: .obs)
    }

    private func remoteAction() {
        model.showingRemoteControl.toggle()
        model.setQuickButton(type: .remote, isOn: model.showingRemoteControl)
    }

    private func drawAction() {
        model.toggleDrawOnStream()
    }

    private func localOverlaysAction() {
        model.toggleQuickButton(type: .localOverlays)
        model.toggleLocalOverlays()
    }

    private func browserAction() {
        model.toggleQuickButton(type: .browser)
        model.toggleBrowser()
    }

    private func navigationAction() {
        model.toggleQuickButton(type: .navigation)
        model.toggleNavigation()
    }

    private func cameraPreviewAction() {
        button.isOn.toggle()
        if button.isOn {
            model.makeToast(
                title: String(localized: "Widgets will not be visible on screen when Camera preview is on"),
                subTitle: String(localized: "They will be visible on stream and in recordings")
            )
        }
        model.toggleCameraPreview()
    }

    private func snapshotAction() {
        model.takeSnapshot()
    }

    private func widgetsAction() {
        model.toggleShowingPanel(type: .widgets, panel: .sceneWidgets)
    }

    private func lutsAction() {
        model.toggleShowingPanel(type: .luts, panel: .luts)
        model.updateLutsButtonState()
    }

    private func chatAction() {
        model.toggleShowingPanel(type: .chat, panel: .chat)
    }

    private func interactiveChatAction() {
        model.toggleQuickButton(type: .interactiveChat)
        model.chat.interactiveChat = button.isOn
        if !button.isOn {
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

    private func replayAction() {
        model.streamOverlay.showingReplay.toggle()
        model.toggleQuickButton(type: .replay)
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

    private func blurTextAction() {
        model.toggleBlurText()
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

    private func sparkleAction() {
        model.triggerSparkle()
    }

    private func beautyAction() {
        model.toggleBeautyQuickButton()
    }

    private func videoPreviewAction() {
        model.toggleVideoPreview()
        model.toggleQuickButton(type: .videoPreview)
    }

    private func interactiveBrowserWidgetsAction() {
        model.setInteractiveBrowserWidgets(on: !button.isOn)
    }

    private func macrosAction() {
        model.toggleShowingPanel(type: .macros, panel: .macros)
    }

    private func gimbalTrackingAction() {
        model.toggleGimbalTracking()
    }

    private func previewStreamAction() {
        model.togglePreviewStream()
    }

    private func photoShootAction() {
        model.toggleQuickButton(type: .photoShoot)
        model.photoShootEnabled = button.isOn
        if model.photoShootEnabled {
            model.startPhotoShoot()
        } else {
            model.stopPhotoShoot()
        }
        model.togglePhotoShoot()
    }

    private func isDisabled() -> Bool {
        !model.isQuickButtonAllowed(type: button.type)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                let buttonView = Group {
                    switch button.type {
                    case .unknown:
                        QuickButtonPlaceholderImage(size: size)
                    case .torch:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            torchAction()
                        }
                    case .mute:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            muteAction()
                        }
                    case .bitrate:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            bitrateAction()
                        }
                    case .mic:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            micAction()
                        }
                    case .chat:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            chatAction()
                        }
                    case .interactiveChat:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            interactiveChatAction()
                        }
                    case .blackScreen:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            stealthModeAction()
                        }
                    case .lockScreen:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            lockScreenAction()
                        }
                    case .record:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            if model.database.startStopRecordingConfirmations {
                                presentingRecordConfirm = true
                            } else {
                                recordAction()
                            }
                        }
                        .confirmationDialog("", isPresented: $presentingRecordConfirm) {
                            Button(button.isOn ? "Stop recording" : "Start recording") {
                                recordAction()
                            }
                        }
                    case .recordings:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            recordingsAction()
                        }
                    case .image:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            imageAction()
                        }
                    case .movie:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            movieAction()
                        }
                    case .fourThree:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            fourThreeAction()
                        }
                    case .crt:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            crtAction()
                        }
                    case .grayScale:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            grayScaleAction()
                        }
                    case .sepia:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            sepiaAction()
                        }
                    case .triple:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            tripleAction()
                        }
                    case .twin:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            twinAction()
                        }
                    case .cameraMan:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                cameraManAction()
                            }
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.white)
                                .stroke(color: button.backgroundColor.color())
                                .offset(CGSize(width: -5, height: 2))
                                .frame(width: size, height: size)
                        }
                    case .pixellate:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            pixellateAction()
                        }
                    case .stream:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            streamAction()
                        }
                    case .grid:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            gridAction()
                        }
                    case .cameraLevel:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            levelAction()
                        }
                    case .obs:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            obsAction()
                        }
                    case .remote:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            remoteAction()
                        }
                    case .draw:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            drawAction()
                        }
                    case .localOverlays:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            localOverlaysAction()
                        }
                    case .browser:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            browserAction()
                        }
                    case .cameraPreview:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            cameraPreviewAction()
                        }
                    case .poll:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            pollAction()
                        }
                    case .snapshot:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            snapshotAction()
                        }
                    case .widgets:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            widgetsAction()
                        }
                    case .luts:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            lutsAction()
                        }
                    case .workout:
                        if button.isOn {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
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
                                             button: button,
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
                                         button: button,
                                         buttonSize: size)
                        {
                            model.presentingModeration = true
                        }
                    case .predefinedMessages:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            model.presentingPredefinedMessages = true
                        }
                    case .skipCurrentTts:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            skipCurrentTtsAction()
                        }
                    case .streamMarker:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            streamMarkerAction()
                        }
                    case .reloadBrowserWidgets:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            reloadBrowserWidgetsAction()
                        }
                    case .djiDevices:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                djiDevicesAction()
                            }
                            ButtonTextOverlayView(text: String(localized: "DJI"))
                        }
                    case .portrait:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            portraitAction()
                        }
                    case .goPro:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                goProAction()
                            }
                            ButtonTextOverlayView(text: String(localized: "GoPro"))
                        }
                    case .replay:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            replayAction()
                        }
                    case .instantReplay:
                        InstantReplayView(model: model, replay: model.replay, button: button, size: size)
                    case .connectionPriorities:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            connectionPrioritiesAction()
                        }
                    case .whirlpool:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            whirlpoolAction()
                        }
                    case .pinch:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            pinchAction()
                        }
                    case .autoSceneSwitcher:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            autoSceneSwitcherAction()
                        }
                    case .pauseTts:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            pauseTtsAction()
                        }
                    case .live:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            liveAction()
                        }
                    case .navigation:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            navigationAction()
                        }
                    case .blurFaces:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            blurFacesAction()
                        }
                    case .blurText:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            blurTextAction()
                        }
                    case .moblinInMouth:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size,
                                             hideImage: true)
                            {
                                moblinInMouthAction()
                            }
                            Image("MoblinInMouth")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 21, height: 40)
                                .offset(.init(width: 0, height: 3))
                        }
                    case .privacy:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            privacyAction()
                        }
                    case .glasses:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            glassesAction()
                        }
                    case .sparkle:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                sparkleAction()
                            }
                            Image(systemName: "sparkle")
                                .rotationEffect(.degrees(70))
                                .offset(CGSize(width: 11, height: 0))
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .frame(width: size, height: size)
                        }
                    case .beauty:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            beautyAction()
                        }
                    case .videoPreview:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            videoPreviewAction()
                        }
                    case .interactiveBrowserWidgets:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            interactiveBrowserWidgetsAction()
                        }
                    case .macros:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            macrosAction()
                        }
                    case .gimbalTracking:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            gimbalTrackingAction()
                        }
                    case .previewStream:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            presentingPreviewStreamConfirm = true
                        }
                        .confirmationDialog("", isPresented: $presentingPreviewStreamConfirm) {
                            Button(button.isOn ? "Stop preview stream" : "Start preview stream") {
                                previewStreamAction()
                            }
                        }
                    case .photoShoot:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            photoShootAction()
                        }
                    }
                }
                if button.type == quickButtons.selectedButtonType {
                    buttonView.overlay(
                        Circle()
                            .stroke(.yellow, lineWidth: 2)
                            .frame(width: size - 2, height: size - 2)
                    )
                } else {
                    buttonView
                }
            }
            if quickButtonsSettings.showName, !orientation.isPortrait {
                Text(button.name)
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
        .disabled(isDisabled())
        .opacity(isDisabled() ? 0.5 : 1)
    }
}
