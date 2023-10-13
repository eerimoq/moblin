import SwiftUI

@main
struct MobsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject static var model = Model()

    init() {
        MobsApp.model.setup()
    }

    var body: some Scene {
        WindowGroup {
            MainView(model: MobsApp.model)
        }
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        MobsApp.model.handleSettingsUrls(urls: connectionOptions.urlContexts)
    }

    func scene(_: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        MobsApp.model.handleSettingsUrls(urls: urlContexts)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    static func setAllowedOrientations(mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        if getWindow()?.rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations() == nil
        {
            logger.error("app: Failed to set allowed orientations. No window.")
        }
    }

    private static func getWindow() -> UIWindow? {
        return UIApplication.shared.connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.last
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

    func application(_: UIApplication,
                     supportedInterfaceOrientationsFor _: UIWindow?)
        -> UIInterfaceOrientationMask
    {
        return AppDelegate.orientationLock
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
}
