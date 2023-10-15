import SwiftUI

struct MaxScreenVideoFpsSettingsView: View {
    @ObservedObject var model: Model

    private func submit(value: String) {
        guard let fps = Int(value), fps > 0 else {
            model.makeErrorToast(title: "FPS must be a positive number")
            return
        }
        model.setMaxScreenVideoFps(fps: fps)
    }

    var body: some View {
        TextEditView(
            title: "Max screen video FPS",
            value: String(model.database.maxScreenVideoFps!),
            onSubmit: submit
        )
    }
}
