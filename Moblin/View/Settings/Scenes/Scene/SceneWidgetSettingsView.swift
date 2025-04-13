import SwiftUI

struct SceneWidgetSettingsView: View {
    @EnvironmentObject private var model: Model
    var sceneWidget: SettingsSceneWidget
    var widget: SettingsWidget

    func submitX(value: Double) {
        sceneWidget.x = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitY(value: Double) {
        sceneWidget.y = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitWidth(value: Double) {
        sceneWidget.width = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitHeight(value: Double) {
        sceneWidget.height = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    private let widgetsWithPosition: [SettingsWidgetType] = [
        .image, .browser, .text, .crop, .map, .qrCode, .alerts, .videoSource,
    ]

    private func widgetHasPosition(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widgetsWithPosition.contains(widget.type)
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private let widgetsWithSize: [SettingsWidgetType] = [
        .image, .qrCode, .map, .videoSource,
    ]

    private func widgetHasSize(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widgetsWithSize.contains(widget.type)
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private func canWidgetExpand(widget: SettingsWidget) -> Bool {
        return widgetHasPosition(id: widget.id) || widgetHasSize(id: widget.id)
    }

    var body: some View {
        Form {
            if widgetHasPosition(id: widget.id) {
                Section {
                    PositionEditView(
                        value: sceneWidget.x,
                        onSubmit: submitX
                    )
                    PositionEditView(
                        value: sceneWidget.y,
                        onSubmit: submitY
                    )
                } header: {
                    Text("Position")
                }
            }
            if widgetHasSize(id: widget.id) {
                Section {
                    SizeEditView(
                        value: sceneWidget.width,
                        onSubmit: submitWidth
                    )
                    SizeEditView(
                        value: sceneWidget.height,
                        onSubmit: submitHeight
                    )
                } header: {
                    Text("Size")
                }
            }
            Section {
                NavigationLink {
                    WidgetSettingsView(
                        widget: widget,
                        type: widget.type.toString(),
                        name: widget.name
                    )
                } label: {
                    Text("Widget")
                }
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle(widget.name)
    }
}
