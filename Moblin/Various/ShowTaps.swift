import UIKit

private let tapDiameter: CGFloat = 44

private class ShowTapsGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let tapsView: UIView
    private var tapViews: [ObjectIdentifier: UIView] = [:]

    init(tapsView: UIView) {
        self.tapsView = tapsView
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        tapsView.superview?.bringSubviewToFront(tapsView)
        for touch in touches {
            let tapView = createTapView()
            tapViews[ObjectIdentifier(touch)] = tapView
            tapsView.addSubview(tapView)
            tapView.center = touch.location(in: tapsView)
        }
        failIfAllTouchesEnded(event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            tapViews[ObjectIdentifier(touch)]?.center = touch.location(in: tapsView)
        }
        failIfAllTouchesEnded(event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        removeTapViews(touches: touches)
        failIfAllTouchesEnded(event: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        removeTapViews(touches: touches)
        failIfAllTouchesEnded(event: event)
    }

    override func canPrevent(_: UIGestureRecognizer) -> Bool {
        false
    }

    override func canBePrevented(by _: UIGestureRecognizer) -> Bool {
        false
    }

    func gestureRecognizer(_: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool
    {
        true
    }

    func removeAllTapViews() {
        for tapView in tapViews.values {
            tapView.removeFromSuperview()
        }
        tapViews.removeAll()
    }

    private func createTapView() -> UIView {
        let tapView = UIView(frame: CGRect(x: 0, y: 0, width: tapDiameter, height: tapDiameter))
        tapView.isUserInteractionEnabled = false
        tapView.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        tapView.layer.cornerRadius = tapDiameter / 2
        tapView.layer.borderWidth = 2
        tapView.layer.borderColor = UIColor.black.withAlphaComponent(0.4).cgColor
        return tapView
    }

    private func removeTapViews(touches: Set<UITouch>) {
        for touch in touches {
            guard let tapView = tapViews.removeValue(forKey: ObjectIdentifier(touch)) else {
                continue
            }
            UIView.animate(withDuration: 0.3) {
                tapView.alpha = 0
                tapView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            } completion: { _ in
                tapView.removeFromSuperview()
            }
        }
    }

    private func failIfAllTouchesEnded(event: UIEvent) {
        let allEnded = event.allTouches?.allSatisfy { $0.phase == .ended || $0.phase == .cancelled } ?? true
        if allEnded {
            state = .failed
        }
    }
}

@MainActor
private class ShowTapsWindow {
    private weak var window: UIWindow?
    private let tapsView = UIView()
    private let gestureRecognizer: ShowTapsGestureRecognizer

    init(window: UIWindow) {
        self.window = window
        tapsView.isUserInteractionEnabled = false
        tapsView.backgroundColor = .clear
        tapsView.frame = window.bounds
        tapsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gestureRecognizer = ShowTapsGestureRecognizer(tapsView: tapsView)
        window.addSubview(tapsView)
        window.addGestureRecognizer(gestureRecognizer)
    }

    func isWindow(_ window: UIWindow) -> Bool {
        self.window === window
    }

    func remove() {
        gestureRecognizer.removeAllTapViews()
        window?.removeGestureRecognizer(gestureRecognizer)
        tapsView.removeFromSuperview()
    }
}

@MainActor
class ShowTaps {
    private var windows: [ShowTapsWindow] = []

    func update(enabled: Bool) {
        if enabled {
            for window in applicationWindows() where !windows.contains(where: { $0.isWindow(window) }) {
                windows.append(ShowTapsWindow(window: window))
            }
        } else {
            for window in windows {
                window.remove()
            }
            windows.removeAll()
        }
    }

    private func applicationWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .filter { $0.session.role == .windowApplication }
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { $0.windowLevel == .normal }
    }
}
