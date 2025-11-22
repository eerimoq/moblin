import SwiftUI

struct WidgetLayoutView: View {
    let model: Model
    @Binding var layout: SettingsWidgetLayout
    @ObservedObject var widget: SettingsWidget
    @Binding var numericInput: Bool

    var body: some View {
        if widget.hasPosition() || widget.hasSize() || widget.hasAlignment() {
            Section {
                if widget.hasPosition() {
                    PositionEditView(
                        number: $layout.x,
                        value: $layout.xString,
                        onSubmit: {
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput,
                        incrementImageName: "arrow.forward.circle",
                        decrementImageName: "arrow.backward.circle",
                        mirror: layout.alignment == .topRight || layout.alignment == .bottomRight
                    )
                    PositionEditView(
                        number: $layout.y,
                        value: $layout.yString,
                        onSubmit: {
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput,
                        incrementImageName: "arrow.down.circle",
                        decrementImageName: "arrow.up.circle",
                        mirror: layout.alignment == .bottomLeft || layout.alignment == .bottomRight
                    )
                }
                if widget.hasSize() {
                    SizeEditView(
                        number: $layout.size,
                        value: $layout.sizeString,
                        onSubmit: {
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput
                    )
                }
                if widget.hasAlignment() {
                    Picker("Alignment", selection: $layout.alignment) {
                        ForEach(SettingsAlignment.allCases, id: \.self) {
                            Text($0.toString())
                                .tag($0)
                        }
                    }
                    .onChange(of: layout.alignment) { _ in
                        model.sceneUpdated()
                    }
                }
            } header: {
                Text("Layout")
            }
        }
    }
}

struct WidgetSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Form {
            Section {
                NameEditView(name: $widget.name, existingNames: database.widgets)
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
                WidgetScoreboardSettingsView(model: model,
                                             widget: widget,
                                             scoreboard: widget.scoreboard)
            case .vTuber:
                WidgetVTuberSettingsView(widget: widget, vTuber: widget.vTuber)
            case .pngTuber:
                WidgetPngTuberSettingsView(widget: widget, pngTuber: widget.pngTuber)
            case .snapshot:
                WidgetSnapshotSettingsView(widget: widget, snapshot: widget.snapshot)
            case .chat:
                WidgetChatSettingsView(widget: widget, chat: widget.chat)
            }
        }
        .navigationTitle("\(widget.type.toString()) widget")
    }
}
