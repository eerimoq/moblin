import AVFoundation
import SwiftUI
import WebKit

struct CloseButtonView: View {
    let onClose: () -> Void

    var body: some View {
        Button {
            onClose()
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: "xmark")
                    .foregroundStyle(.foreground)
                    .frame(width: 12, height: 12)
                    .padding()
                    .glassEffect()
                    .padding(2)
            } else {
                Image(systemName: "xmark")
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

struct CloseButtonTopRightView: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Spacer()
            VStack {
                CloseButtonView(onClose: onClose)
                    .padding()
                Spacer()
            }
        }
    }
}

private struct HideShowButtonPanelView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.panelHidden.toggle()
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: model.panelHidden ? "eye" : "eye.slash")
                    .foregroundStyle(.foreground)
                    .frame(width: 12, height: 12)
                    .padding()
                    .glassEffect()
                    .padding(2)
            } else {
                Image(systemName: model.panelHidden ? "eye" : "eye.slash")
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

private struct PanelButtonsView: View {
    let model: Model
    let backgroundColor: Color

    private func onClose() {
        model.toggleShowingPanel(type: nil, panel: .none)
        model.updateLutsButtonState()
        model.updateAutoSceneSwitcherButtonState()
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                if #available(iOS 26, *) {
                    HStack(spacing: 0) {
                        HideShowButtonPanelView()
                        CloseButtonView {
                            onClose()
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        HideShowButtonPanelView()
                        CloseButtonView {
                            onClose()
                        }
                    }
                    .padding(-3)
                    .background(backgroundColor)
                    .cornerRadius(7)
                    .padding(3)
                }
                Spacer()
            }
        }
    }
}

private struct MenuView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        switch model.showingPanel {
        case .settings:
            NavigationStack {
                SettingsView(database: model.database)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .bitrate:
            NavigationStack {
                QuickButtonBitrateView(model: model, database: model.database, stream: model.stream)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .mic:
            NavigationStack {
                QuickButtonMicView(model: model, mics: model.database.mics, modelMic: model.mic)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .streamSwitcher:
            NavigationStack {
                QuickButtonStreamSwitcherView(database: model.database)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .luts:
            NavigationStack {
                QuickButtonLutsView(model: model, color: model.database.color)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .obs:
            NavigationStack {
                QuickButtonObsView(stream: model.stream, obsQuickButton: model.obsQuickButton)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .sceneWidgets:
            NavigationStack {
                QuickButtonSceneWidgetsView(sceneSelector: model.sceneSelector)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .store:
            NavigationStack {
                StoreSettingsView(model: model, store: model.store)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .chat:
            NavigationStack {
                QuickButtonChatView(model: model,
                                    orientation: model.orientation,
                                    quickButtonChat: model.quickButtonChatState)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .djiDevices:
            NavigationStack {
                QuickButtonDjiDevicesView(model: model, djiDevices: model.database.djiDevices)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .sceneSettings:
            NavigationStack {
                SceneSettingsView(database: model.database, scene: model.sceneSettingsPanelScene)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .id(model.sceneSettingsPanelSceneId)
        case .goPro:
            NavigationStack {
                QuickButtonGoProView(goProState: model.goPro, goPro: model.database.goPro)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .connectionPriorities:
            NavigationStack {
                StreamSrtConnectionPriorityView(stream: model.stream)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .autoSceneSwitcher:
            NavigationStack {
                QuickButtonAutoSceneSwitcherView(
                    autoSceneSwitcher: model.autoSceneSwitcher,
                    autoSceneSwitchers: model.database.autoSceneSwitchers
                )
                .navigationBarTitleDisplayMode(.inline)
            }
        case .quickButtonSettings:
            NavigationStack {
                if let button = model.quickButtonSettingsButton {
                    QuickButtonsButtonSettingsView(model: model,
                                                   orientation: model.orientation,
                                                   quickButtonsSettings: model.database.quickButtonsGeneral,
                                                   button: button,
                                                   showAll: true)
                        .navigationBarTitleDisplayMode(.inline)
                        .id(button.id)
                }
            }
        case .streamingButtonSettings:
            NavigationStack {
                StreamButtonsSettingsView(database: model.database)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .live:
            NavigationStack {
                QuickButtonLiveView(model: model, database: model.database, stream: model.stream)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .macros:
            NavigationStack {
                QuickButtonMacrosView(model: model, macros: model.database.macros)
                    .navigationBarTitleDisplayMode(.inline)
            }
        case .none:
            EmptyView()
        }
    }
}

struct BrowserWidgetView: UIViewRepresentable {
    let browser: Browser

    func makeUIView(context _: Context) -> WKWebView {
        browser.browserEffect.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        browser.browserEffect.reload()
    }
}

private struct InstantReplayCountdownView: View {
    @ObservedObject var replay: ReplayProvider

    var body: some View {
        if replay.instantReplayCountdown != 0 {
            VStack {
                Text("Playing instant replay in")
                Text(String(replay.instantReplayCountdown))
                    .font(.title)
            }
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 200, alignment: .center)
            .padding(10)
            .background(.black.opacity(0.75))
            .cornerRadius(10)
        }
    }
}

private struct MutedView: View {
    @ObservedObject var audio: AudioProvider

    var body: some View {
        if audio.muted {
            Image(systemName: "microphone.slash")
                .font(.system(size: 80))
                .foregroundStyle(.red)
                .padding(10)
                .background(.black.opacity(0.75))
                .cornerRadius(10)
                .allowsHitTesting(false)
        }
    }
}

private struct PhotoShootFlashButtonView: View {
    @ObservedObject var database: Database

    var body: some View {
        Button {
            database.photoShootFlash.toggle()
        } label: {
            Image(systemName: database.photoShootFlash ? "bolt.fill" : "bolt.slash.fill")
                .font(.system(size: 30))
                .foregroundStyle(database.photoShootFlash ? .yellow : .white)
                .frame(width: 60, height: 60)
                .background(.black.opacity(0.75))
                .clipShape(Circle())
        }
    }
}

private struct PhotoShootIntervalPickerView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        Menu {
            Picker("", selection: Binding(get: {
                database.photoShootInterval
            }, set: { interval in
                model.setPhotoShootInterval(interval: interval)
            })) {
                ForEach([1, 2, 3, 10, 60], id: \.self) { interval in
                    Text(formatShortDuration(seconds: interval))
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.system(size: 24))
                Text(verbatim: "\(database.photoShootInterval)s")
                    .font(.system(size: 14))
            }
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(.black.opacity(0.75))
            .clipShape(Circle())
        }
    }
}

private struct PhotoShootCountdownView: View {
    @ObservedObject var photoShoot: PhotoShootProvider

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { _ in
            let remaining = if let nextPhotoTime = photoShoot.nextPhotoTime {
                max((nextPhotoTime - .now).seconds, 0)
            } else {
                photoShoot.interval
            }
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: remaining / photoShoot.interval)
                    .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "\(max(Int(remaining.rounded(.up)), 1))")
                    .font(.system(size: 28, weight: .bold))
                    .monospacedDigit()
            }
            .frame(width: 70, height: 70)
        }
    }
}

private struct PhotoShootInfoView: View {
    @ObservedObject var photoShoot: PhotoShootProvider

    var body: some View {
        VStack {
            Text("Photo shoot")
                .font(.system(size: 30))
            PhotoShootCountdownView(photoShoot: photoShoot)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(photoShoot.photoTaken ? .white.opacity(0.75) : .black.opacity(0.75))
        .cornerRadius(10)
        .animation(photoShoot.photoTaken ? nil : .easeOut(duration: 0.2), value: photoShoot.photoTaken)
        .allowsHitTesting(false)
    }
}

private struct PhotoShootView: View {
    let model: Model
    let photoShoot: PhotoShootProvider
    let enabled: Bool

    var body: some View {
        if enabled {
            VStack(spacing: 15) {
                PhotoShootInfoView(photoShoot: photoShoot)
                HStack(spacing: 15) {
                    PhotoShootIntervalPickerView(model: model, database: model.database)
                    if model.cameraDevice?.hasFlash == true {
                        PhotoShootFlashButtonView(database: model.database)
                    }
                }
            }
        }
    }
}

private struct WebBrowserAlertsView: UIViewControllerRepresentable {
    let model: Model

    func makeUIViewController(context _: Context) -> WebBrowserController {
        model.webBrowserController
    }

    func updateUIViewController(_: WebBrowserController, context _: Context) {}
}

private struct StreamOverlayTapGridView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState
    let size: CGSize

    func drawFocus(context: GraphicsContext, size: CGSize, focusPoint: CGPoint) {
        let sideLength = 70.0
        let x = size.width * focusPoint.x - sideLength / 2
        let y = size.height * focusPoint.y - sideLength / 2
        let origin = CGPoint(x: x, y: y)
        let size = CGSize(width: sideLength, height: sideLength)
        context.stroke(
            Path(roundedRect: CGRect(origin: origin, size: size), cornerRadius: 2.0),
            with: .color(.yellow),
            lineWidth: 1
        )
    }

    private func tapToFocusIndicator(size: CGSize, focusPoint: CGPoint) -> some View {
        Canvas { context, _ in
            drawFocus(context: context, size: size, focusPoint: focusPoint)
        }
        .allowsHitTesting(false)
    }

    var body: some View {
        if model.database.tapToFocus, let focusPoint = camera.manualFocusPoint {
            tapToFocusIndicator(size: size, focusPoint: focusPoint)
        }
        if model.showingGrid {
            StreamGridView()
        }
        if model.showingCameraLevel {
            CameraLevelView(cameraLevel: model.cameraLevel)
        }
    }
}

private struct InteractiveBrowserView: View {
    let browser: Browser
    @ObservedObject var browserEffect: BrowserEffect
    let streamSize: CGSize

    var body: some View {
        if let layout = browserEffect.layout {
            let browserSize = CGSize(width: browserEffect.width, height: browserEffect.height)
            let scale = layoutScale(layout, browserSize, streamSize)
            let displaySize = CGSize(
                width: scale * browserSize.width,
                height: scale * browserSize.height
            )
            BrowserWidgetView(browser: browser)
                .frame(width: browserSize.width, height: browserSize.height)
                .scaleEffect(scale)
                .frame(width: displaySize.width, height: displaySize.height)
                .position(layoutCenter(layout, displaySize, streamSize))
        }
    }
}

struct MainView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowserController: WebBrowserController
    let streamView: StreamView
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @ObservedObject var toast: Toast
    @ObservedObject var orientation: Orientation
    @ObservedObject var quickButtons: SettingsQuickButtons

    init(webBrowserController: WebBrowserController,
         streamView: StreamView,
         createStreamWizard: CreateStreamWizard,
         toast: Toast,
         orientation: Orientation,
         quickButtons: SettingsQuickButtons)
    {
        self.webBrowserController = webBrowserController
        self.streamView = streamView
        self.createStreamWizard = createStreamWizard
        self.toast = toast
        self.orientation = orientation
        self.quickButtons = quickButtons
        UITextField.appearance().clearButtonMode = .always
    }

    private func handleTapToFocus(size: CGSize, location: CGPoint) {
        guard model.database.tapToFocus else {
            return
        }
        let x = (location.x / size.width).clamped(to: 0 ... 1)
        let y = (location.y / size.height).clamped(to: 0 ... 1)
        model.setFocusPointOfInterest(focusPoint: CGPoint(x: x, y: y))
    }

    private func handleLeaveTapToFocus() {
        guard model.database.tapToFocus else {
            return
        }
        model.setAutoFocus()
    }

    private func browserWidgets(streamSize: CGSize) -> some View {
        ZStack {
            ForEach(model.browsers) { browser in
                InteractiveBrowserView(browser: browser,
                                       browserEffect: browser.browserEffect,
                                       streamSize: streamSize)
            }
        }
        .frame(width: streamSize.width, height: streamSize.height)
        .opacity(model.interactiveBrowsers ? 1 : 0)
        .allowsHitTesting(model.interactiveBrowsers)
    }

    private func streamViewWithWidgets() -> some View {
        GeometryReader { metrics in
            let layout = model.streamViewLayout(metrics: metrics)
            ZStack {
                streamView
                    .onTapGesture(count: 1) {
                        handleTapToFocus(size: layout.size, location: $0)
                    }
                    .onLongPressGesture {
                        handleLeaveTapToFocus()
                    }
                StreamOverlayTapGridView(camera: model.camera, size: layout.size)
                browserWidgets(streamSize: layout.size)
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .offset(layout.offset)
        }
    }

    private func portrait() -> some View {
        VStack(spacing: 0) {
            ZStack {
                streamViewWithWidgets()
                GeometryReader { metrics in
                    StreamOverlayView(streamOverlay: model.streamOverlay,
                                      chatSettings: model.database.chat,
                                      orientation: orientation,
                                      width: metrics.size.width)
                        .padding(.bottom, orientation.isPortrait ? 5 : 0)
                        .opacity(model.showLocalOverlays ? 1 : 0)
                }
                if model.showDrawOnStream, model.stream.portrait {
                    DrawOnStreamView(model: model)
                }
                MutedView(audio: model.audio)
                PhotoShootView(model: model, photoShoot: model.photoShoot, enabled: model.photoShootEnabled)
                if model.showBrowser {
                    WebBrowserView(model: model,
                                   database: model.database,
                                   orientation: orientation,
                                   webBrowserState: model.webBrowserState)
                }
                if model.showNavigation {
                    if #available(iOS 26, *) {
                        StreamOverlayNavigationView(model: model,
                                                    database: model.database,
                                                    navigation: model.navigation())
                    }
                }
                if model.showingRemoteControl {
                    ControlBarRemoteControlAssistantView(model: model,
                                                         remoteControlSettings: model.database.remoteControl)
                }
                if model.showingPanel != .none {
                    MenuView()
                        .opacity(model.panelHidden ? 0 : 1)
                    let backgroundColor = model.panelHidden ? model.showingPanel
                        .buttonsBackgroundColor() : .clear
                    PanelButtonsView(model: model, backgroundColor: backgroundColor)
                        .padding(.trailing, 10)
                        .padding(.top, -7)
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { amount in
                        model.changeZoomX(amount: Float(amount))
                    }
                    .onEnded { amount in
                        model.commitZoomX(amount: Float(amount))
                    }
            )
            ControlBarPortraitView(model: model, quickButtons: quickButtons)
        }
    }

    private func landscape() -> some View {
        HStack(spacing: 0) {
            ZStack {
                streamViewWithWidgets()
                GeometryReader { metrics in
                    StreamOverlayView(streamOverlay: model.streamOverlay,
                                      chatSettings: model.database.chat,
                                      orientation: orientation,
                                      width: metrics.size.width)
                        .opacity(model.showLocalOverlays ? 1 : 0)
                }
                if model.showDrawOnStream {
                    DrawOnStreamView(model: model)
                }
                MutedView(audio: model.audio)
                PhotoShootView(model: model, photoShoot: model.photoShoot, enabled: model.photoShootEnabled)
                if model.showBrowser {
                    WebBrowserView(model: model,
                                   database: model.database,
                                   orientation: orientation,
                                   webBrowserState: model.webBrowserState)
                }
                if model.showNavigation {
                    if #available(iOS 26, *) {
                        StreamOverlayNavigationView(model: model,
                                                    database: model.database,
                                                    navigation: model.navigation())
                    }
                }
                if model.showingRemoteControl {
                    ControlBarRemoteControlAssistantView(model: model,
                                                         remoteControlSettings: model.database.remoteControl)
                }
                if model.showingPanel != .none, model.panelHidden {
                    PanelButtonsView(
                        model: model,
                        backgroundColor: model.showingPanel.buttonsBackgroundColor()
                    )
                    .padding(.trailing, -1)
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { amount in
                        model.changeZoomX(amount: Float(amount))
                    }
                    .onEnded { amount in
                        model.commitZoomX(amount: Float(amount))
                    }
            )
            if model.showingPanel != .none {
                ZStack {
                    MenuView()
                        .opacity(model.panelHidden ? 0 : 1)
                        .background(.black)
                    if !model.panelHidden {
                        PanelButtonsView(model: model, backgroundColor: .clear)
                    }
                }
                .frame(width: model.panelHidden ? 1 : settingsHalfWidth)
            }
            ControlBarLandscapeView(model: model, quickButtons: quickButtons)
        }
    }

    private func edgesToIgnore() -> Edge.Set {
        if isPhone() {
            if orientation.isPortrait {
                if quickButtons.bigButtons, quickButtons.twoColumns {
                    [.bottom]
                } else {
                    []
                }
            } else if quickButtons.bigButtons, quickButtons.twoColumns {
                [.top, .trailing]
            } else {
                [.top]
            }
        } else {
            []
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            let all = ZStack {
                if orientation.isPortrait {
                    portrait()
                } else {
                    landscape()
                }
                WebBrowserAlertsView(model: model)
                    .opacity(webBrowserController.showAlert ? 1 : 0)
                if model.showStealthMode {
                    StealthModeView(
                        model: model,
                        quickButtons: quickButtons,
                        chat: model.chat,
                        chatAlerts: model.chatActivityFeed,
                        stealthMode: model.stealthMode,
                        orientation: orientation
                    )
                }
                if model.lockScreen {
                    LockScreenView(model: model)
                }
                SnapshotCountdownView(snapshot: model.snapshot)
                InstantReplayCountdownView(replay: model.replay)
            }
            .onAppear {
                model.setup()
            }
            .sheet(isPresented: $model.showTwitchAuth) {
                TwitchLoginView(model: model, presenting: $model.showTwitchAuth)
            }
            .sheet(isPresented: $model.presentingModeration) {
                QuickButtonChatModerationView(model: model, presentingModeration: $model.presentingModeration)
            }
            .sheet(isPresented: $model.presentingPredefinedMessages) {
                PredefinedMessagesView(model: model,
                                       chat: model.database.chat,
                                       filter: model.database.chat.predefinedMessagesFilter,
                                       presentingPredefinedMessages: $model.presentingPredefinedMessages)
            }
            .confirmationDialog(
                "Are you sure you want to import settings? This will replace your current settings.",
                isPresented: $model.presentingSettingsImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Import settings", role: .destructive) {
                    model.pendingSettingsImportAction?()
                    model.pendingSettingsImportAction = nil
                }
            }
            .confirmationDialog(
                model.pendingStreamImportCollisionTitle,
                isPresented: $model.presentingStreamImportCollisionConfirmation,
                titleVisibility: .visible
            ) {
                Button("Create new") {
                    model.pendingStreamImportCollisionAction?(false)
                    model.pendingStreamImportCollisionAction = nil
                }
                Button("Merge", role: .destructive) {
                    model.pendingStreamImportCollisionAction?(true)
                    model.pendingStreamImportCollisionAction = nil
                }
            }
            .toast(isPresenting: $toast.showingToast, duration: 5) {
                toast.toast
            } onTap: {
                model.toast.onTapped?()
            }
            .persistentSystemOverlays(.hidden)
            #if targetEnvironment(macCatalyst)
            all
            #else
            if #available(iOS 18.0, *) {
                all
                    .background {
                        Color.black
                            .onCameraCaptureEvent(isEnabled: model.cameraControlEnabled) { event in
                                if event.phase == .ended {
                                    // model.takeSnapshot()
                                }
                            }
                    }
            } else {
                all
            }
            #endif
            Rectangle()
                .foregroundStyle(.black)
                .frame(height: isMac() ? 10 : 0)
        }
        .background {
            KeyPressView(model: model)
                .frame(width: 0, height: 0)
        }
        .ignoresSafeArea(.container, edges: edgesToIgnore())
    }
}
