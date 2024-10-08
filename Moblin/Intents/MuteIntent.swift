import AppIntents

struct MuteIntent: AppIntent {
    static var title: LocalizedStringResource = "Mute"
    static var description: IntentDescription? = IntentDescription("Mutes audio.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        model.setMuted(value: true)
        model.setGlobalButtonState(type: .mute, isOn: true)
        model.updateButtonStates()
        return .result()
    }

    @Dependency
    private var model: Model
}
