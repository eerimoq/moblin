import SwiftUI
import UIKit

private class MacKeyPressUIView: UIView {
    var onKeyPress: ((String) -> Bool)?
    var observer: NSObjectProtocol?

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let characters = press.key?.characters, !characters.isEmpty {
                if onKeyPress?(characters) == true {
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            observer = NotificationCenter.default.addObserver(
                forName: UIWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.claimFocus()
            }
            DispatchQueue.main.async {
                self.claimFocus()
            }
        } else if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}

struct MacKeyPressView: UIViewRepresentable {
    let model: Model

    func makeUIView(context _: Context) -> MacKeyPressUIView {
        let view = MacKeyPressUIView()
        view.backgroundColor = .clear
        view.onKeyPress = { characters in
            model.handleKeyPressCharacters(characters)
        }
        return view
    }

    func updateUIView(_: MacKeyPressUIView, context _: Context) {}
}
