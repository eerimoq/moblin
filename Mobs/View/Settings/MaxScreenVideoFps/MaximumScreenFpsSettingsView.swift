import SwiftUI

struct MaximumScreenFpsSettingsView: View {
    @ObservedObject var model: Model

    private func submit(value: String) {
        guard let fps = Int(value), fps > 0 else {
            model.makeErrorToast(title: "FPS must be a positive number")
            return
        }
        model.setMaximumScreenFps(fps: fps)
    }

    var body: some View {
        TextEditView(
            title: "Maximum screen FPS",
            value: String(model.database.maximumScreenFps!),
            onSubmit: submit
        )
    }
}
