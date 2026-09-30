import UIKit

extension Model {
    func handleKeyPresses(_ presses: Set<UIPress>, pressed: Bool) -> Bool {
        var handled = false
        for press in presses {
            guard let key = press.key, !key.characters.isEmpty else {
                continue
            }
            guard key.modifierFlags.isDisjoint(with: [.command, .control]) else {
                continue
            }
            guard let keyboardKey = database.keyboard.keys.first(where: { $0.key == key.characters }) else {
                continue
            }
            DispatchQueue.main.async {
                self.handleControllerFunction(buttonId: "kb:\(keyboardKey.key)",
                                              function: keyboardKey.function,
                                              functionData: keyboardKey.functionData,
                                              pressed: pressed)
            }
            handled = true
        }
        return handled
    }
}
