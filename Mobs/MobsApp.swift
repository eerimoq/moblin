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
        if UIApplication.shared.windows.first?.rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations() == nil
        {
            logger.error("app: Failed to set allowed orientations. No window.")
        }
    }

    func application(_: UIApplication,
                     supportedInterfaceOrientationsFor _: UIWindow?)
        -> UIInterfaceOrientationMask
    {
        return AppDelegate.orientationLock
    }
}
