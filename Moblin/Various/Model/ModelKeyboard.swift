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
        if showModerationAuth {
            return false
        }
        if createStreamWizard.presenting {
            return false
        }
        if createStreamWizard.presentingSetup {
            return false
        }
        if createStreamWizard.showTwitchAuth {
            return false
        }
        return true
    }

    func handleKeyPressCharacters(_ characters: String) -> Bool {
        guard isKeyboardActive() else {
            return false
        }
        guard let key = database.keyboard.keys.first(where: { $0.key == characters }) else {
            return false
        }
        DispatchQueue.main.async {
            self.handleControllerFunction(buttonId: "kb:\(key.key)",
                                          function: key.function,
                                          functionData: key.functionData,
                                          pressed: false)
        }
        return true
    }

    @available(iOS 17.0, *)
    func handleKeyPress(press: KeyPress) -> KeyPress.Result {
        handleKeyPressCharacters(press.characters) ? .handled : .ignored
    }
}
