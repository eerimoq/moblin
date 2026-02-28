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
    @EnvironmentObject var model: Model
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
            }
        case .bitrate:
            NavigationStack {
                QuickButtonBitrateView(model: model, database: model.database, stream: model.stream)
            }
        case .mic:
            NavigationStack {
                QuickButtonMicView(model: model, mics: model.database.mics, modelMic: model.mic)
            }
        case .streamSwitcher:
            NavigationStack {
                QuickButtonStreamSwitcherView(database: model.database)
            }
        case .luts:
            NavigationStack {
                QuickButtonLutsView(model: model, color: model.database.color)
            }
        case .obs:
            NavigationStack {
                QuickButtonObsView(stream: model.stream, obsQuickButton: model.obsQuickButton)
            }
        case .sceneWidgets:
            NavigationStack {
                QuickButtonSceneWidgetsView(sceneSelector: model.sceneSelector)
            }
        case .recordings:
            NavigationStack {
                RecordingsSettingsView(model: model)
            }
        case .store:
            NavigationStack {
                StoreSettingsView(store: model.store)
            }
        case .chat:
            NavigationStack {
                QuickButtonChatView(model: model, quickButtonChat: model.quickButtonChatState)
            }
        case .djiDevices:
            NavigationStack {
                QuickButtonDjiDevicesView(model: model, djiDevices: model.database.djiDevices)
            }
        case .sceneSettings:
            NavigationStack {
                SceneSettingsView(database: model.database, scene: model.sceneSettingsPanelScene)
            }
            .id(model.sceneSettingsPanelSceneId)
        case .goPro:
            NavigationStack {
                QuickButtonGoProView(goProState: model.goPro, goPro: model.database.goPro)
            }
        case .connectionPriorities:
            NavigationStack {
                StreamSrtConnectionPriorityView(stream: model.stream)
            }
        case .autoSceneSwitcher:
            NavigationStack {
                QuickButtonAutoSceneSwitcherView(
                    autoSceneSwitcher: model.autoSceneSwitcher,
                    autoSceneSwitchers: model.database.autoSceneSwitchers
                )
            }
        case .quickButtonSettings:
            NavigationStack {
                if let button = model.quickButtonSettingsButton {
                    QuickButtonsButtonSettingsView(model: model,
                                                   orientation: model.orientation,
                                                   quickButtonsSettings: model.database.quickButtonsGeneral,
                                                   button: button)
                }
            }
        case .streamingButtonSettings:
            NavigationStack {
                StreamButtonsSettingsView(database: model.database)
            }
        case .live:
            NavigationStack {
                QuickButtonLiveView(model: model, database: model.database, stream: model.stream)
            }
        case .none:
            EmptyView()
        }
    }
}

struct BrowserWidgetView: UIViewRepresentable {
    let browser: Browser

    func makeUIView(context _: Context) -> WKWebView {
        return browser.browserEffect.webView
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
    @ObservedObject var level: AudioLevel

    var body: some View {
        if level.isMuted() {
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

private struct WebBrowserAlertsView: UIViewControllerRepresentable {
    @EnvironmentObject var model: Model

    func makeUIViewController(context _: Context) -> WebBrowserController {
        return model.webBrowserController
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

struct MainView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowserController: WebBrowserController
    let streamView: StreamView
    @FocusState private var focused: Bool
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

    private func handleTapToFocus(metrics: GeometryProxy, location: CGPoint) {
        guard model.database.tapToFocus else {
            return
        }
        let x = (location.x / metrics.size.width).clamped(to: 0 ... 1)
        let y = (location.y / metrics.size.height).clamped(to: 0 ... 1)
        model.setFocusPointOfInterest(focusPoint: CGPoint(x: x, y: y))
    }

    private func handleLeaveTapToFocus() {
        guard model.database.tapToFocus else {
            return
        }
        model.setAutoFocus()
    }

    private func browserWidgets() -> some View {
        ForEach(model.browsers) { browser in
            ScrollView([.vertical, .horizontal]) {
                BrowserWidgetView(browser: browser)
                    .frame(
                        width: browser.browserEffect.width,
                        height: browser.browserEffect.height
                    )
                    .opacity(0)
            }
            .frame(width: browser.browserEffect.width, height: browser.browserEffect.height)
            .allowsHitTesting(false)
        }
    }

    private func streamAspectRatio() -> CGFloat {
        return model.stream.dimensions().aspectRatio()
    }

    private func portraitVideoOffset() -> Double {
        if model.stream.portrait {
            return 0
        } else {
            return model.portraitVideoOffsetFromTop
        }
    }

    private func portrait() -> some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Spacer(minLength: 0)
                    VStack {
                        GeometryReader { metrics in
                            ZStack {
                                streamView
                                    .onTapGesture(count: 1) {
                                        handleTapToFocus(metrics: metrics, location: $0)
                                    }
                                    .onLongPressGesture {
                                        handleLeaveTapToFocus()
                                    }
                                StreamOverlayTapGridView(camera: model.camera, size: metrics.size)
                            }
                            .offset(CGSize(
                                width: 0,
                                height: portraitVideoOffset() * metrics.size.height * 2
                            ))
                        }
                        .aspectRatio(streamAspectRatio(), contentMode: .fit)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()
                GeometryReader { metrics in
                    StreamOverlayView(streamOverlay: model.streamOverlay,
                                      chatSettings: model.database.chat,
                                      orientation: orientation,
                                      width: metrics.size.width)
                        .opacity(model.showLocalOverlays ? 1 : 0)
                }
                if model.showDrawOnStream, model.stream.portrait {
                    DrawOnStreamView(model: model)
                }
                MutedView(level: model.audio.level)
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
                    ControlBarRemoteControlAssistantView(model: model)
                }
                if model.showingPanel != .none {
                    MenuView()
                        .opacity(model.panelHidden ? 0 : 1)
                    let backgroundColor = model.panelHidden ? model.showingPanel
                        .buttonsBackgroundColor() : .clear
                    PanelButtonsView(backgroundColor: backgroundColor)
                        .padding([.trailing], 10)
                        .padding([.top], -7)
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
            ControlBarPortraitView(quickButtons: quickButtons)
        }
    }

    private func landscape() -> some View {
        HStack(spacing: 0) {
            ZStack {
                HStack {
                    Spacer(minLength: 0)
                    VStack {
                        Spacer(minLength: 0)
                        GeometryReader { metrics in
                            ZStack {
                                streamView
                                    .onTapGesture(count: 1) {
                                        handleTapToFocus(metrics: metrics, location: $0)
                                    }
                                    .onLongPressGesture {
                                        handleLeaveTapToFocus()
                                    }
                                StreamOverlayTapGridView(camera: model.camera, size: metrics.size)
                            }
                        }
                        .aspectRatio(streamAspectRatio(), contentMode: .fit)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()
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
                MutedView(level: model.audio.level)
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
                    ControlBarRemoteControlAssistantView(model: model)
                }
                if model.showingPanel != .none, model.panelHidden {
                    PanelButtonsView(backgroundColor: model.showingPanel.buttonsBackgroundColor())
                        .padding([.trailing], -1)
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
                        PanelButtonsView(backgroundColor: .clear)
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
                if quickButtons.bigButtons && quickButtons.twoColumns {
                    return [.bottom]
                } else {
                    return []
                }
            } else if quickButtons.bigButtons && quickButtons.twoColumns {
                return [.top, .trailing]
            } else {
                return [.top]
            }
        } else if isMac() {
            return [.top]
        } else {
            return []
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
                WebBrowserAlertsView()
                    .opacity(webBrowserController.showAlert ? 1 : 0)
                if model.showStealthMode {
                    StealthModeView(
                        model: model,
                        quickButtons: quickButtons,
                        chat: model.chat,
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
            .overlay(alignment: .topLeading) {
                browserWidgets()
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
            .toast(isPresenting: $toast.showingToast, duration: 5) {
                toast.toast
            } onTap: {
                model.toast.onTapped?()
            }
            .persistentSystemOverlays(.hidden)
            if #available(iOS 17.0, *) {
                let all = all
                    .focusable()
                    .focused($focused)
                    .onKeyPress { press in
                        model.handleKeyPress(press: press)
                    }
                    .onChange(of: model.showingPanel) { _ in
                        focused = model.isKeyboardActive()
                    }
                    .onChange(of: model.showBrowser) { _ in
                        focused = model.isKeyboardActive()
                    }
                    .onChange(of: model.showTwitchAuth) { _ in
                        focused = model.isKeyboardActive()
                    }
                    .onChange(of: createStreamWizard.presenting) { _ in
                        focused = model.isKeyboardActive()
                    }
                    .onChange(of: createStreamWizard.presentingSetup) { _ in
                        focused = model.isKeyboardActive()
                    }
                    .onChange(of: createStreamWizard.showTwitchAuth) { _ in
                        focused = model.isKeyboardActive()
                    }
                    .onAppear {
                        focused = true
                    }
                if #available(iOS 18.0, *) {
                    all
                        .onCameraCaptureEvent(isEnabled: model.cameraControlEnabled) { event in
                            if event.phase == .ended {
                                // model.takeSnapshot()
                            }
                        }
                } else {
                    all
                }
            } else {
                all
            }
            Rectangle()
                .foregroundStyle(.black)
                .frame(height: isMac() ? 10 : 0)
        }
        .ignoresSafeArea(.container, edges: edgesToIgnore())
    }
}
