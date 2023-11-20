import SwiftUI

struct SceneCameraPipSmallCameraSettingsView: View {
    @EnvironmentObject private var model: Model
    var scene: SettingsScene

    func submitX(value: Double) {
        scene.cameraLayoutPip!.x = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitY(value: Double) {
        scene.cameraLayoutPip!.y = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitWidth(value: Double) {
        scene.cameraLayoutPip!.width = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitHeight(value: Double) {
        scene.cameraLayoutPip!.height = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    var body: some View {
        Section {
            PositionEditView(
                title: "X",
                value: scene.cameraLayoutPip!.x,
                onSubmit: submitX
            )
            PositionEditView(
                title: "Y",
                value: scene.cameraLayoutPip!.y,
                onSubmit: submitY
            )
            SizeEditView(
                title: "Width",
                value: scene.cameraLayoutPip!.width,
                onSubmit: submitWidth
            )
            SizeEditView(
                title: "Height",
                value: scene.cameraLayoutPip!.height,
                onSubmit: submitHeight
            )
        }
    }
}
