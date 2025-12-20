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
        guard isKeyboardActive() else {
            return .ignored
        }
        guard let key = database.keyboard.keys.first(where: { $0.key == press.characters }) else {
            return .ignored
        }
        DispatchQueue.main.async {
            self.handleControllerFunction(function: key.function,
                                          sceneId: key.sceneId,
                                          widgetId: key.widgetId,
                                          pressed: false)
        }
        return .handled
    }
}
