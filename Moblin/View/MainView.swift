import SwiftUI
import WebKit

private struct CloseButtonView: View {
    var onClose: () -> Void

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(.gray)
                        )
                        .foregroundColor(.gray)
                        .padding(7)
                }
                Spacer()
            }
        }
    }
}

private struct CloseButtonPanelView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        CloseButtonView {
            model.toggleShowingPanel(type: nil, panel: .none)
            model.updateLutsButtonState()
        }
    }
}

private struct MenuView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ZStack {
            switch model.showingPanel {
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            case .bitrate:
                NavigationStack {
                    QuickButtonBitrateView(selection: model.stream.bitrate)
                }
            case .mic:
                NavigationStack {
                    QuickButtonMicView(selectedMic: model.currentMic)
                }
            case .streamSwitcher:
                NavigationStack {
                    QuickButtonStreamView()
                }
            case .luts:
                NavigationStack {
                    QuickButtonLutsView()
                }
            case .obs:
                NavigationStack {
                    QuickButtonObsView()
                }
            case .widgets:
                NavigationStack {
                    QuickButtonWidgetsView()
                }
            case .recordings:
                NavigationStack {
                    RecordingsSettingsView()
                }
            case .cosmetics:
                NavigationStack {
                    CosmeticsSettingsView()
                }
            case .chat:
                NavigationStack {
                    QuickButtonChatView()
                }
            case .djiDevices:
                NavigationStack {
                    QuickButtonDjiDevicesView()
                }
            case .sceneSettings:
                NavigationStack {
                    SceneSettingsView(scene: model.sceneSettingsPanelScene,
                                      name: model.sceneSettingsPanelScene.name,
                                      selectedRotation: model.sceneSettingsPanelScene.videoSourceRotation!,
                                      numericInput: model.database.sceneNumericInput!)
                }
                .id(model.sceneSettingsPanelSceneId)
            case .goPro:
                NavigationStack {
                    QuickButtonGoProView()
                }
            case .connectionPriorities:
                NavigationStack {
                    QuickButtonConnectionPrioritiesView()
                }
            case .none:
                EmptyView()
            }
            CloseButtonPanelView()
        }
    }
}

private struct CloseButtonRemoteView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        CloseButtonView {
            model.showingRemoteControl = false
            model.setGlobalButtonState(type: .remote, isOn: model.showingRemoteControl)
            model.updateButtonStates()
        }
    }
}

struct BrowserWidgetView: UIViewRepresentable {
    var browser: Browser

    func makeUIView(context _: Context) -> WKWebView {
        return browser.browserEffect.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        browser.browserEffect.reload()
    }
}

private struct FindFaceView: View {
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                VStack {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 30))
                    Text("Find a face")
                }
                .foregroundColor(.white)
                .padding(5)
                .background(backgroundColor)
                .cornerRadius(5)
                Spacer()
            }
            Spacer()
        }
    }
}

private struct SnapshotCountdownView: View {
    @EnvironmentObject var model: Model
    let message: String

    var body: some View {
        VStack {
            Text("Taking snapshot in")
            Text(String(model.snapshotCountdown))
                .font(.title)
            Text(message)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.white)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 300, alignment: .center)
        .padding(10)
        .background(.black.opacity(0.75))
        .cornerRadius(10)
    }
}

private struct InstantReplayCountdownView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack {
            Text("Playing instant replay in")
            Text(String(model.instantReplayCountdown))
                .font(.title)
        }
        .foregroundColor(.white)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 200, alignment: .center)
        .padding(10)
        .background(.black.opacity(0.75))
        .cornerRadius(10)
    }
}

private struct WebBrowserAlertsView: UIViewControllerRepresentable {
    @EnvironmentObject var model: Model

    func makeUIViewController(context _: Context) -> WebBrowserController {
        return model.webBrowserController
    }

    func updateUIViewController(_: WebBrowserController, context _: Context) {}
}

struct MainView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowserController: WebBrowserController
    var streamView: StreamView
    var webBrowserView: WebBrowserView
    @State var showAreYouReallySure = false
    @FocusState private var focused: Bool

    func drawFocus(context: GraphicsContext, metrics: GeometryProxy, focusPoint: CGPoint) {
        let sideLength = 70.0
        let x = metrics.size.width * focusPoint.x - sideLength / 2
        let y = metrics.size.height * focusPoint.y - sideLength / 2
        let origin = CGPoint(x: x, y: y)
        let size = CGSize(width: sideLength, height: sideLength)
        context.stroke(
            Path(roundedRect: CGRect(origin: origin, size: size), cornerRadius: 2.0),
            with: .color(.yellow),
            lineWidth: 1
        )
    }

    private var debug: SettingsDebug {
        model.database.debug
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

    private func tapToFocusIndicator(metrics: GeometryProxy, focusPoint: CGPoint) -> some View {
        Canvas { context, _ in
            drawFocus(context: context, metrics: metrics, focusPoint: focusPoint)
        }
        .allowsHitTesting(false)
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

    private func face() -> some View {
        FaceView(
            crop: debug.beautyFilter!,
            beauty: debug.beautyFilterSettings!.showBeauty!,
            blur: debug.beautyFilterSettings!.showBlur,
            blurBackground: debug.beautyFilterSettings!.showBlurBackground!,
            mouth: debug.beautyFilterSettings!.showMoblin
        )
    }

    private func portraitAspectRatio() -> CGFloat {
        if model.stream.portrait! {
            return 9 / 16
        } else {
            return 16 / 9
        }
    }

    private func portraitVideoOffset() -> Double {
        if model.stream.portrait! {
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
                                    .onLongPressGesture(perform: {
                                        handleLeaveTapToFocus()
                                    })
                                if model.database.tapToFocus, let focusPoint = model.manualFocusPoint {
                                    tapToFocusIndicator(metrics: metrics, focusPoint: focusPoint)
                                }
                                if model.showingGrid {
                                    StreamGridView()
                                }
                            }
                            .offset(CGSize(
                                width: 0,
                                height: portraitVideoOffset() * metrics.size.height * 2
                            ))
                        }
                        .aspectRatio(portraitAspectRatio(), contentMode: .fit)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .background(.black)
                .ignoresSafeArea()
                .edgesIgnoringSafeArea(.all)
                GeometryReader { metrics in
                    StreamOverlayView(width: metrics.size.width, height: metrics.size.height)
                        .opacity(model.showLocalOverlays ? 1 : 0)
                }
                if model.showFace && !model.showDrawOnStream {
                    face()
                }
                if model.showBrowser {
                    webBrowserView
                }
                if model.showingRemoteControl {
                    ZStack {
                        NavigationStack {
                            ControlBarRemoteControlAssistantView()
                        }
                        CloseButtonRemoteView()
                    }
                }
                if model.showingPanel != .none {
                    MenuView()
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
            ControlBarPortraitView()
        }
        .overlay(alignment: .topLeading) {
            browserWidgets()
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
                                    .onLongPressGesture(perform: {
                                        handleLeaveTapToFocus()
                                    })
                                if model.database.tapToFocus, let focusPoint = model.manualFocusPoint {
                                    tapToFocusIndicator(metrics: metrics, focusPoint: focusPoint)
                                }
                                if model.showingGrid {
                                    StreamGridView()
                                }
                            }
                        }
                        .aspectRatio(16 / 9, contentMode: .fit)
                        Spacer(minLength: 0)
                    }
                }
                .background(.black)
                .ignoresSafeArea()
                .edgesIgnoringSafeArea(.all)
                GeometryReader { metrics in
                    StreamOverlayView(width: metrics.size.width, height: metrics.size.height)
                        .opacity(model.showLocalOverlays ? 1 : 0)
                }
                if model.showDrawOnStream {
                    DrawOnStreamView()
                }
                if model.showFace && !model.showDrawOnStream {
                    face()
                }
                if model.showBrowser {
                    webBrowserView
                }
                if model.showingRemoteControl {
                    ZStack {
                        NavigationStack {
                            ControlBarRemoteControlAssistantView()
                        }
                        CloseButtonRemoteView()
                    }
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
                MenuView()
                    .frame(width: settingsHalfWidth)
            }
            ControlBarLandscapeView()
        }
        .overlay(alignment: .topLeading) {
            browserWidgets()
        }
    }

    var body: some View {
        let all = ZStack {
            if model.stream.portrait! || model.database.portrait! {
                portrait()
            } else {
                landscape()
            }
            WebBrowserAlertsView()
                .opacity(webBrowserController.showAlert ? 1 : 0)
            if model.blackScreen {
                Text("")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .onTapGesture(count: 2) { _ in
                        model.toggleBlackScreen()
                    }
            }
            if model.lockScreen {
                Text("")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.01))
                    .onTapGesture(count: 2) { _ in
                        model.toggleLockScreen()
                    }
            }
            if model.findFace {
                FindFaceView()
            }
            if let snapshotJob = model.currentSnapshotJob, model.snapshotCountdown > 0 {
                SnapshotCountdownView(message: snapshotJob.message)
            }
            if model.instantReplayCountdown != 0 {
                InstantReplayCountdownView()
            }
        }
        .onAppear {
            model.setup()
        }
        .sheet(isPresented: $model.showTwitchAuth) {
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        model.showTwitchAuth = false
                    }, label: {
                        Text("Close").padding()
                    })
                }
                ScrollView {
                    TwitchAuthView(twitchAuth: model.twitchAuth)
                        .frame(height: 2500)
                }
            }
        }
        .toast(isPresenting: $model.showingToast, duration: 5) {
            model.toast
        }
        .alert("⚠️ Failed to load settings ⚠️", isPresented: $model.showLoadSettingsFailed) {
            Button("Delete old settings and continue", role: .cancel) {
                showAreYouReallySure = true
            }
        } message: {
            Text("Immediately install the old version of the app to keep your old settings.")
        }
        .alert("⚠️ Deleting old settings ⚠️", isPresented: $showAreYouReallySure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "Immediately install the old version of the app to keep your old settings. This is the last warning!"
            )
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
                .onChange(of: model.isPresentingWizard) { _ in
                    focused = model.isKeyboardActive()
                }
                .onChange(of: model.isPresentingSetupWizard) { _ in
                    focused = model.isKeyboardActive()
                }
                .onChange(of: model.wizardShowTwitchAuth) { _ in
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
    }
}
