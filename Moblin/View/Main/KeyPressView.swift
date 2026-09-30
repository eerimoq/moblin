import SwiftUI
import UIKit

private extension UIResponder {
    private weak static var foundFirstResponder: UIResponder?

    @objc private func noteFirstResponder() {
        UIResponder.foundFirstResponder = self
    }

    static func currentFirstResponder() -> UIResponder? {
        foundFirstResponder = nil
        UIApplication.shared.sendAction(#selector(noteFirstResponder), to: nil, from: nil, for: nil)
        return foundFirstResponder
    }
}

class KeyPressUIView: UIView {
    var model: Model?
    private let reclaimFocusTimer = MainTimer()

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        claimFocus()
    }

    override func resignFirstResponder() -> Bool {
        reclaimFocusTimer.startPeriodic(interval: 1) { [weak self] in
            self?.claimFocus()
        }
        return super.resignFirstResponder()
    }

    private func claimFocus() {
        guard window != nil else {
            reclaimFocusTimer.stop()
            return
        }
        guard !isFirstResponder else {
            reclaimFocusTimer.stop()
            return
        }
        let current = UIResponder.currentFirstResponder()
        guard current == nil || current is UIApplication || current is UIWindow else {
            return
        }
        if becomeFirstResponder() {
            reclaimFocusTimer.stop()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if model?.handleKeyPresses(presses, pressed: true) != true {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if model?.handleKeyPresses(presses, pressed: false) != true {
            super.pressesEnded(presses, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if model?.handleKeyPresses(presses, pressed: false) != true {
            super.pressesCancelled(presses, with: event)
        }
    }
}

struct KeyPressView: UIViewRepresentable {
    let model: Model

    func makeUIView(context _: Context) -> KeyPressUIView {
        let view = KeyPressUIView()
        view.backgroundColor = .clear
        view.model = model
        return view
    }

    func updateUIView(_: KeyPressUIView, context _: Context) {}
}
