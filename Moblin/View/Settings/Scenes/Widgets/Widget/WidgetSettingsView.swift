import SwiftUI

struct WidgetSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Form {
            Section {
                NameEditView(name: $widget.name, existingNames: database.widgets)
                Picker("Type", selection: $widget.type) {
                    ForEach(widgetTypes, id: \.self) { type in
                        Text(type.toString())
                    }
                }
                .onChange(of: widget.type) { _ in
                    model.resetSelectedScene(changeScene: false)
                }
            }
            switch widget.type {
            case .image:
                WidgetImageSettingsView(widget: widget)
            case .browser:
                WidgetBrowserSettingsView(widget: widget, browser: widget.browser)
            case .text:
                WidgetTextSettingsView(widget: widget, text: widget.text)
            case .crop:
                WidgetCropSettingsView(widget: widget)
            case .map:
                WidgetMapSettingsView(widget: widget, delay: widget.map.delay)
            case .scene:
                WidgetSceneSettingsView(widget: widget, selectedSceneId: widget.scene.sceneId)
            case .qrCode:
                WidgetQrCodeSettingsView(widget: widget)
            case .alerts:
                WidgetAlertsSettingsView(model: model, widget: widget)
            case .videoSource:
                WidgetVideoSourceSettingsView(widget: widget, videoSource: widget.videoSource)
            case .scoreboard:
                WidgetScoreboardSettingsView(model: model, scoreboard: widget.scoreboard)
            case .vTuber:
                WidgetVTuberSettingsView(widget: widget, vTuber: widget.vTuber)
            case .pngTuber:
                WidgetPngTuberSettingsView(widget: widget, pngTuber: widget.pngTuber)
            case .snapshot:
                WidgetSnapshotSettingsView(widget: widget, snapshot: widget.snapshot)
            }
        }
        .navigationTitle("Widget")
    }
}
