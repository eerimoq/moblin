import AppIntents

struct UnmuteIntent: AppIntent {
    static var title: LocalizedStringResource = "Unmute"
    static var description: IntentDescription? = IntentDescription("Unmutes audio.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        model.setMuted(value: false)
        model.setGlobalButtonState(type: .mute, isOn: false)
        model.updateQuickButtonStates()
        return .result()
    }

    @Dependency
    private var model: Model
}
