import AppIntents

struct SnapshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Take snapshot"
    static let description: IntentDescription? = IntentDescription("Take a snapshot.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        model.takeSnapshot()
        return .result()
    }

    @Dependency
    private var model: Model
}
