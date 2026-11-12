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

    private func iconSize() -> Font {
        if quickButtonsSettings.bigButtons {
            .system(size: 20)
        } else {
            .body
        }
    }

    private func image() -> some View {
        Image(systemName: getImage())
            .font(iconSize())
            .frame(width: buttonSize, height: buttonSize)
            .foregroundStyle(foregroundColor())
    }

    private func onRing() -> some View {
        Circle()
            .stroke(.white)
            .frame(width: buttonSize - 1, height: buttonSize - 1)
    }

    var body: some View {
        let image = image()
        ZStack {
            if button.isOn {
                image.overlay(onRing())
            } else {
                image
            }
        }
        .contentShape(Circle())
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
    let onTapped: () -> Void

    private func timeLeft() -> some View {
        Text(String(replay.timeLeft))
            .font(.system(size: 25))
            .frame(width: size, height: size)
            .foregroundStyle(.white)
            .contentShape(Circle())
    }

    var body: some View {
        if replay.isPlaying {
            timeLeft()
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
                onTapped()
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
    let model: Model
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
        model.takeSnapshot(age: 0.0, isChatBot: false, message: nil)
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
        model.chatActivityFeed.interactiveChat = button.isOn
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
        model.attachCamera()
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
        model.togglePhotoShoot()
    }

    private func sceneEditorAction() {
        model.presentingSceneEditor = true
    }

    private func selectedRing() -> some View {
        Circle()
            .stroke(.yellow, lineWidth: 2)
            .frame(width: size - 2, height: size - 2)
    }

    private func isPresentingDialog() -> Bool {
        presentingRecordConfirm
            || presentingPreviewStreamConfirm
            || presentingStartWorkoutTypePicker
            || presentingStopWorkoutConfirm
    }

    private func stopFilteringUnlessPresentingDialog() {
        if isPresentingDialog() {
            model.quickButtonsFilterPresentingDialog()
        } else {
            model.stopFilteringQuickButtons(showButton: button)
        }
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .mute:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            muteAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .bitrate:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            bitrateAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .mic:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            micAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .chat:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            chatAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .interactiveChat:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            interactiveChatAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .blackScreen:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            stealthModeAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .lockScreen:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            lockScreenAction()
                            stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                        .confirmationDialog("", isPresented: $presentingRecordConfirm) {
                            Button(button.isOn ? "Stop recording" : "Start recording") {
                                recordAction()
                            }
                        }
                    case .image:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            imageAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .movie:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            movieAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .fourThree:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            fourThreeAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .crt:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            crtAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .grayScale:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            grayScaleAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .sepia:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            sepiaAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .triple:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            tripleAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .twin:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            twinAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .cameraMan:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                cameraManAction()
                                stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .stream:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            streamAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .grid:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            gridAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .cameraLevel:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            levelAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .obs:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            obsAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .remote:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            remoteAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .draw:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            drawAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .localOverlays:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            localOverlaysAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .browser:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            browserAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .cameraPreview:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            cameraPreviewAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .poll:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            pollAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .snapshot:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            snapshotAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .widgets:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            widgetsAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .luts:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            lutsAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .workout:
                        if button.isOn {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                presentingStopWorkoutConfirm = true
                                stopFilteringUnlessPresentingDialog()
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
                                stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .predefinedMessages:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            model.presentingPredefinedMessages = true
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .skipCurrentTts:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            skipCurrentTtsAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .streamMarker:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            streamMarkerAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .reloadBrowserWidgets:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            reloadBrowserWidgetsAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .djiDevices:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                djiDevicesAction()
                                stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .goPro:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                goProAction()
                                stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .instantReplay:
                        InstantReplayView(
                            model: model,
                            replay: model.replay,
                            button: button,
                            size: size,
                            onTapped: stopFilteringUnlessPresentingDialog
                        )
                    case .connectionPriorities:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            connectionPrioritiesAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .whirlpool:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            whirlpoolAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .pinch:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            pinchAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .autoSceneSwitcher:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            autoSceneSwitcherAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .pauseTts:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            pauseTtsAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .live:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            liveAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .navigation:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            navigationAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .blurFaces:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            blurFacesAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .blurText:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            blurTextAction()
                            stopFilteringUnlessPresentingDialog()
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
                                stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .glasses:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            glassesAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .sparkle:
                        ZStack {
                            QuickButtonImage(model: model,
                                             quickButtonsSettings: quickButtonsSettings,
                                             button: button,
                                             buttonSize: size)
                            {
                                sparkleAction()
                                stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .videoPreview:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            videoPreviewAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .interactiveBrowserWidgets:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            interactiveBrowserWidgetsAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .macros:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            macrosAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .gimbalTracking:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            gimbalTrackingAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .previewStream:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            presentingPreviewStreamConfirm = true
                            stopFilteringUnlessPresentingDialog()
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
                            stopFilteringUnlessPresentingDialog()
                        }
                    case .sceneEditor:
                        QuickButtonImage(model: model,
                                         quickButtonsSettings: quickButtonsSettings,
                                         button: button,
                                         buttonSize: size)
                        {
                            sceneEditorAction()
                            stopFilteringUnlessPresentingDialog()
                        }
                    }
                }
                if button.type == .unknown {
                    buttonView
                } else if button.type == quickButtons.selectedButtonType {
                    buttonView
                        .overlay(selectedRing())
                        .background(Circle().fill(button.backgroundColor.color()))
                } else {
                    buttonView
                        .background(Circle().fill(button.backgroundColor.color()))
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
        .onChange(of: isPresentingDialog()) { presenting in
            if !presenting {
                model.stopFilteringQuickButtons(showButton: button)
            }
        }
        .id(button.id)
    }
}

private struct ScrollToQuickButtonModifier: ViewModifier {
    let model: Model
    @ObservedObject var quickButtons: QuickButtons
    let pairs: [QuickButtonPair]
    let proxy: ScrollViewProxy

    private func scroll() {
        if let buttonId = model.takeQuickButtonToScrollTo(pairs: pairs) {
            proxy.scrollTo(buttonId, anchor: .center)
        }
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                scroll()
            }
            .onChange(of: quickButtons.scrollToButtonId) { _ in
                scroll()
            }
    }
}

extension View {
    func scrollToQuickButton(model: Model,
                             quickButtons: QuickButtons,
                             pairs: [QuickButtonPair],
                             proxy: ScrollViewProxy) -> some View
    {
        modifier(ScrollToQuickButtonModifier(model: model,
                                             quickButtons: quickButtons,
                                             pairs: pairs,
                                             proxy: proxy))
    }
}
