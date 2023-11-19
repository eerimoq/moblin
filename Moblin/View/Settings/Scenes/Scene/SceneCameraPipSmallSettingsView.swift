import SwiftUI

struct SceneCameraPipSmallSettingsView: View {
    @EnvironmentObject private var model: Model
    var scene: SettingsScene

    func submitX(value: String) {
        if let value = Double(value) {
            scene.cameraLayoutPip!.x = value.clamped(to: 0 ... 99)
            model.store()
            model.sceneUpdated(imageEffectChanged: true)
        }
    }

    func submitY(value: String) {
        if let value = Double(value) {
            scene.cameraLayoutPip!.y = value.clamped(to: 0 ... 99)
            model.sceneUpdated(imageEffectChanged: true)
        }
    }

    func submitW(value: String) {
        if let value = Double(value) {
            scene.cameraLayoutPip!.width = value.clamped(to: 1 ... 100)
            model.sceneUpdated(imageEffectChanged: true)
        }
    }

    func submitH(value: String) {
        if let value = Double(value) {
            scene.cameraLayoutPip!.height = value.clamped(to: 1 ... 100)
            model.sceneUpdated(imageEffectChanged: true)
        }
    }

    var body: some View {
        Section {
            ValueEditView(
                title: "X",
                value: String(scene.cameraLayoutPip!.x),
                minimum: 0,
                maximum: 99,
                onSubmit: submitX
            )
            ValueEditView(
                title: "Y",
                value: String(scene.cameraLayoutPip!.y),
                minimum: 0,
                maximum: 99,
                onSubmit: submitY
            )
            ValueEditView(
                title: "Width",
                value: String(scene.cameraLayoutPip!.width),
                minimum: 1,
                maximum: 100,
                onSubmit: submitW
            )
            ValueEditView(
                title: "Height",
                value: String(scene.cameraLayoutPip!.height),
                minimum: 1,
                maximum: 100,
                onSubmit: submitH
            )
        }
    }
}
