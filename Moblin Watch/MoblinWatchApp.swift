import SwiftUI

@main
struct MoblinWatchApp: App {
    @StateObject var model: Model
    static var globalModel: Model?

    init() {
        MoblinWatchApp.globalModel = Model()
        _model = StateObject(wrappedValue: MoblinWatchApp.globalModel!)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(model)
        }
    }
}
