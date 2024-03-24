import SwiftUI

struct SceneWidgetSettingsView: View {
    @EnvironmentObject private var model: Model
    let hasPosition: Bool
    let hasSize: Bool
    var widget: SettingsSceneWidget

    func submitX(value: Double) {
        widget.x = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitY(value: Double) {
        widget.y = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitWidth(value: Double) {
        widget.width = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitHeight(value: Double) {
        widget.height = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    var body: some View {
        Section {
            if hasPosition {
                PositionEditView(
                    title: String(localized: "X"),
                    value: widget.x,
                    onSubmit: submitX
                )
                PositionEditView(
                    title: String(localized: "Y"),
                    value: widget.y,
                    onSubmit: submitY
                )
            }
            if hasSize {
                SizeEditView(
                    title: String(localized: "Width"),
                    value: widget.width,
                    onSubmit: submitWidth
                )
                SizeEditView(
                    title: String(localized: "Height"),
                    value: widget.height,
                    onSubmit: submitHeight
                )
            }
        }
    }
}
