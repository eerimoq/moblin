import AVFoundation
import SwiftUI

@main
struct MobsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private var settings: Settings = {
        let settings = Settings()
        settings.load()
        // ToDo: Remove. Just for testing.
        //settings.store()
        return settings
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    let session = AVAudioSession.sharedInstance()
    do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
    } catch {
            print(error)
    }
        return true
    }
}
