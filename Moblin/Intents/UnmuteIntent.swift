import AppIntents

struct UnmuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Unmute"
    static let description: IntentDescription? = IntentDescription("Unmutes audio.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        model.setMuted(value: false)
        model.setQuickButton(type: .mute, isOn: false)
        model.updateQuickButtonStates()
        return .result()
    }

    @Dependency
    private var model: Model
}
