import SwiftUI
import UIKit

class MacKeyPressUIView: UIView {
    var model: Model?

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let characters = press.key?.characters, !characters.isEmpty {
                if model?.handleKeyPressCharacters(characters) == true {
                    handled = true
                }
            }
        }
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    func claimFocus() {
        if !isFirstResponder {
            becomeFirstResponder()
        }
    }
}

struct MacKeyPressView: UIViewRepresentable {
    let model: Model
    let shouldClaimFocus: Bool

    func makeUIView(context _: Context) -> MacKeyPressUIView {
        let view = MacKeyPressUIView()
        view.backgroundColor = .clear
        view.model = model
        return view
    }

    func updateUIView(_ uiView: MacKeyPressUIView, context _: Context) {
        if shouldClaimFocus {
            DispatchQueue.main.async { [weak uiView] in
                uiView?.claimFocus()
            }
        }
    }
}
