import SwiftUI

@main
struct MoblinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var model: Model
    static var globalModel: Model?

    init() {
        MoblinApp.globalModel = Model()
        _model = StateObject(wrappedValue: MoblinApp.globalModel!)
    }

    var body: some Scene {
        WindowGroup {
            MainView(
                streamView: StreamView(
                    cameraPreviewView: CameraPreviewView(),
                    streamPreviewView: StreamPreviewView()
                ),
                webBrowserView: WebBrowserView()
            )
            .environmentObject(model)
        }
    }
}

private struct ExternalScreenContentView: View {
    @StateObject var model: Model

    init() {
        _model = StateObject(wrappedValue: MoblinApp.globalModel!)
    }

    var body: some View {
        ExternalDisplayView()
            .ignoresSafeArea()
            .environmentObject(model)
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    // periphery:ignore
    var externalDisplayWindow: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let model = MoblinApp.globalModel else {
            return
        }
        model.handleSettingsUrls(urls: connectionOptions.urlContexts)
        if session.role == .windowExternalDisplayNonInteractive, let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: ExternalScreenContentView())
            externalDisplayWindow = window
            window.makeKeyAndVisible()
            model.externalDisplayPreview = true
            model.reattachCamera()
        }
    }

    func sceneDidDisconnect(_: UIScene) {
        externalDisplayWindow = nil
        guard let model = MoblinApp.globalModel else {
            return
        }
        model.externalDisplayPreview = false
        model.reattachCamera()
    }

    func scene(_: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        MoblinApp.globalModel?.handleSettingsUrls(urls: urlContexts)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .landscape {
        didSet {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    windowScene
                        .requestGeometryUpdate(
                            .iOS(interfaceOrientations: orientationLock)
                        )
                }
            }
            // For some reason new way of doing this does not work in all
            // cases. See repo log.
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }

    func application(
        _: UIApplication,
        willFinishLaunchingWithOptions _: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(_: UIApplication,
                     supportedInterfaceOrientationsFor _: UIWindow?)
        -> UIInterfaceOrientationMask
    {
        return AppDelegate.orientationLock
    }
}
