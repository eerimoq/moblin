import AVFoundation
import SwiftUI

@main
struct MobsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
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
}
