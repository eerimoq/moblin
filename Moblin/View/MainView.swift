import SpriteKit
import SwiftUI
import WebKit

struct BrowserView: UIViewRepresentable {
    var browser: Browser

    func makeUIView(context _: Context) -> WKWebView {
        // print("Make browser UI view", browser.browserEffect.url.host()!)
        return browser.browserEffect.webView
    }

    func updateUIView(_: WKWebView, context _: Context) {
        browser.browserEffect.reload()
        // print("Update browser UI view", browser.browserEffect.url.host()!)
    }
}

class SnowScene: SKScene {
    let snowEmitterNode = SKEmitterNode(fileNamed: "Snow.sks")

    override func didMove(to _: SKView) {
        guard let snowEmitterNode = snowEmitterNode else {
            return
        }
        snowEmitterNode.particleSize = CGSize(width: 50, height: 50)
        snowEmitterNode.particleLifetime = 8
        snowEmitterNode.particleLifetimeRange = 12
        addChild(snowEmitterNode)
    }

    override func didChangeSize(_: CGSize) {
        guard let snowEmitterNode = snowEmitterNode else {
            return
        }
        snowEmitterNode.particlePosition = CGPoint(x: size.width / 2, y: size.height)
        snowEmitterNode.particlePositionRange = CGVector(dx: size.width, dy: size.height)
    }
}

struct MainView: View {
    @EnvironmentObject var model: Model
    var streamView: StreamView
    @State var showAreYouReallySure = false

    private var scene: SKScene {
        let scene = SnowScene()
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        return scene
    }

    private func settingsWidth(width: Double) -> Double {
        if model.settingsLayout == .full {
            return width
        } else {
            return settingsHalfWidth
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ZStack {
                    GeometryReader { metrics in
                        streamView
                            .ignoresSafeArea()
                            .onTapGesture(count: 1) { location in
                                guard model.database.tapToFocus else {
                                    return
                                }
                                let x = (location.x / metrics.size.width)
                                    .clamped(to: 0 ... 1)
                                let y = (location.y / metrics.size.height)
                                    .clamped(to: 0 ... 1)
                                model.setFocusPointOfInterest(focusPoint: CGPoint(
                                    x: x,
                                    y: y
                                ))
                            }
                            .onLongPressGesture(perform: {
                                guard model.database.tapToFocus else {
                                    return
                                }
                                model.setAutoFocus()
                            })
                        if model.showingGrid {
                            StreamGridView()
                                .ignoresSafeArea()
                        }
                        ForEach(model.browsers) { browser in
                            BrowserView(browser: browser)
                                .frame(
                                    width: browser.browserEffect.width,
                                    height: browser.browserEffect.height
                                )
                                .opacity(0)
                        }
                    }
                    if model.showLocalOverlays {
                        StreamOverlayView()
                    }
                    if model.showDrawOnStream {
                        DrawOnStreamView()
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
                ControlBarView()
            }
            if model.showingSettings {
                GeometryReader { metrics in
                    HStack {
                        if model.settingsLayout == .right {
                            Spacer()
                        }
                        NavigationStack {
                            SettingsView()
                        }
                        .frame(width: settingsWidth(width: metrics.size.width))
                        .background(Color(uiColor: .systemGroupedBackground))
                        if model.settingsLayout == .left {
                            Spacer()
                        }
                    }
                }
            }
            if model.showingBitrate {
                HStack {
                    Spacer()
                    NavigationStack {
                        StreamVideoBitrateSettingsButtonView(selection: model.stream
                            .bitrate)
                        {
                            model.showingBitrate = false
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.showingMic {
                HStack {
                    Spacer()
                    NavigationStack {
                        MicButtonView(selectedMic: model.mic) {
                            model.showingMic = false
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.showingStreamSwitcher {
                HStack {
                    Spacer()
                    NavigationStack {
                        StreamSwitcherView {
                            model.showingStreamSwitcher = false
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.showingCamera {
                HStack {
                    Spacer()
                    NavigationStack {
                        CameraView {
                            model.showingCamera = false
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.showingObs {
                HStack {
                    Spacer()
                    NavigationStack {
                        ObsView {
                            model.showingObs = false
                            model.stopObsSourceScreenshot()
                            model.stopObsAudioVolume()
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.showingRemoteControl {
                NavigationStack {
                    RemoteControlView {
                        model.showingRemoteControl = false
                    }
                }
            }
            if model.showingRecordings {
                HStack {
                    Spacer()
                    NavigationStack {
                        RecordingsSettingsView(quickDone: {
                            model.showingRecordings = false
                        })
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.database.debug!.letItSnow! {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            if model.blackScreen {
                Text("")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .onTapGesture(count: 2) { _ in
                        model.toggleBlackScreen()
                    }
                    .persistentSystemOverlays(.hidden)
            }
        }
        .onAppear {
            model.setup()
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
    }
}
