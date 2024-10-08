import AppIntents

struct SnapshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Take snapshot"
    static var description: IntentDescription? = IntentDescription("Take a snapshot.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        model.takeSnapshot()
        return .result()
    }

    @Dependency
    private var model: Model
}
