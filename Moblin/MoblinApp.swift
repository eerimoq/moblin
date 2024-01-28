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
            MainView(streamView: StreamView())
                .environmentObject(model)
                // .persistentSystemOverlays(.hidden)
        }
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        MoblinApp.globalModel?.handleSettingsUrls(urls: connectionOptions.urlContexts)
    }

    func scene(_: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        MoblinApp.globalModel?.handleSettingsUrls(urls: urlContexts)
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
