import AppIntents

struct MuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute"
    static let description: IntentDescription? = IntentDescription("Mutes audio.")
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        model.setMuted(value: true)
        model.setQuickButton(type: .mute, isOn: true)
        model.updateQuickButtonStates()
        return .result()
    }

    @Dependency
    private var model: Model
}
