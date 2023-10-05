import AVFoundation
import SwiftUI

@main
struct MobsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private var settings: Settings = {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let settings = Settings()
        settings.load()
        return settings
    }()

    var body: some Scene {
        WindowGroup {
            MainView(settings: settings)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    static func setAllowedOrientations(mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        let windows = UIApplication.shared.windows
        guard windows.count > 0 else {
            logger.error("app: Failed to set allowed orientations. No window.")
            return
        }
        if let controller = windows[0].rootViewController {
            controller.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    func application(_: UIApplication,
                     supportedInterfaceOrientationsFor _: UIWindow?)
        -> UIInterfaceOrientationMask
    {
        return AppDelegate.orientationLock
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            logger.error("app: Session error \(error)")
        }
        return true
    }
}
