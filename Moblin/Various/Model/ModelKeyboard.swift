import SwiftUI

extension Model {
    func isKeyboardActive() -> Bool {
        if showingPanel != .none {
            return false
        }
        if showBrowser {
            return false
        }
        if showTwitchAuth {
            return false
        }
        if createStreamWizard.isPresenting {
            return false
        }
        if createStreamWizard.isPresentingSetup {
            return false
        }
        if createStreamWizard.showTwitchAuth {
            return false
        }
        return true
    }

    @available(iOS 17.0, *)
    func handleKeyPress(press: KeyPress) -> KeyPress.Result {
        let charactersHex = press.characters.data(using: .utf8)?.hexString() ?? "???"
        logger.info("""
        keyboard: Press characters \"\(press.characters)\" (\(charactersHex)), \
        modifiers \(press.modifiers), key \(press.key), phase \(press.phase)
        """)
        guard isKeyboardActive() else {
            return .ignored
        }
        guard let key = database.keyboard.keys.first(where: { $0.key == press.characters }) else {
            return .ignored
        }
        switch key.function {
        case .unused:
            break
        case .record:
            toggleRecording()
        case .stream:
            toggleStream()
        case .torch:
            toggleTorch()
            toggleGlobalButton(type: .torch)
        case .mute:
            toggleMute()
            toggleGlobalButton(type: .mute)
        case .blackScreen:
            toggleStealthMode()
        case .scene:
            selectScene(id: key.sceneId)
        case .widget:
            toggleWidgetOnOff(id: key.widgetId)
        case .instantReplay:
            instantReplay()
        }
        updateQuickButtonStates()
        return .handled
    }
}
