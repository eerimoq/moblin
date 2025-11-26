import AVKit
import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct AudioInputPickerButton: UIViewRepresentable {
    class Coordinator: NSObject {
        let interaction = AVInputPickerInteraction()
        weak var view: UIView?

        @objc func handleTap() {
            interaction.present()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Input", for: .normal)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        context.coordinator.view = button
        button.addInteraction(context.coordinator.interaction)
        return button
    }

    func updateUIView(_: UIButton, context _: Context) {}
}
