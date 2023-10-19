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
}
