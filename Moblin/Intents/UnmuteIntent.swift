import AppIntents

struct UnmuteIntent: AppIntent {
    static var title: LocalizedStringResource = "Unmute"
    static var description: IntentDescription? = IntentDescription("Opens the app and unmutes.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        model.setMuted(value: false)
        model.setGlobalButtonState(type: .mute, isOn: false)
        model.updateButtonStates()
        return .result()
    }

    @Dependency
    private var model: Model
}
