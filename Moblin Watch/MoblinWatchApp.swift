import SwiftUI

@main
struct MoblinWatchApp: App {
    @StateObject var model: WatchModel
    static var globalModel: WatchModel?

    init() {
        MoblinWatchApp.globalModel = WatchModel()
        _model = StateObject(wrappedValue: MoblinWatchApp.globalModel!)
    }

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(model)
        }
    }
}
