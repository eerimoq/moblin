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
                    if !layout.alignment.isCenter() {
                        PositionEditView(
                            number: $layout.x,
                            value: $layout.xString,
                            onSubmit: {
                                model.sceneUpdated()
                            },
                            numericInput: $numericInput,
                            incrementImageName: "arrow.forward.circle",
                            decrementImageName: "arrow.backward.circle",
                            mirror: layout.alignment.mirrorPositionHorizontally()
                        )
                    }
                    PositionEditView(
                        number: $layout.y,
                        value: $layout.yString,
                        onSubmit: {
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput,
                        incrementImageName: "arrow.down.circle",
                        decrementImageName: "arrow.up.circle",
                        mirror: layout.alignment.mirrorPositionVertically()
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

struct WidgetNameView: View {
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        HStack {
            Image(systemName: widget.image())
            Text(widget.name)
        }
    }
}

struct WidgetSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Form {
            Section {
                NameEditView(name: $widget.name, existingNames: database.widgets)
            }
            WidgetLayoutView(model: model,
                             layout: $widget.layout,
                             widget: widget,
                             numericInput: $database.sceneNumericInput)
            if widget.canExpand() {
                Section {
                    Toggle("Numeric input", isOn: $database.sceneNumericInput)
                }
            }
            switch widget.type {
            case .image:
                WidgetImageSettingsView(model: model, widget: widget)
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
            case .slideshow:
                WidgetSlideshowSettingsView(widget: widget)
            case .qrCode:
                WidgetQrCodeSettingsView(model: model, widget: widget)
            case .alerts:
                WidgetAlertsSettingsView(model: model, widget: widget)
            case .videoSource:
                WidgetVideoSourceSettingsView(widget: widget, videoSource: widget.videoSource)
            case .scoreboard:
                WidgetScoreboardSettingsView(model: model,
                                             widget: widget,
                                             scoreboard: widget.scoreboard,
                                             web: database.remoteControl.web)
            case .vTuber:
                WidgetVTuberSettingsView(model: model, widget: widget, vTuber: widget.vTuber)
            case .pngTuber:
                WidgetPngTuberSettingsView(model: model, widget: widget, pngTuber: widget.pngTuber)
            case .snapshot:
                WidgetSnapshotSettingsView(model: model, widget: widget, snapshot: widget.snapshot)
            case .chat:
                WidgetChatSettingsView(model: model, database: database, widget: widget, chat: widget.chat)
            case .wheelOfLuck:
                WidgetWheelOfLuckSettingsView(model: model, widget: widget, wheelOfLuck: widget.wheelOfLuck)
            case .bingoCard:
                WidgetBingoCardSettingsView(model: model, widget: widget, bingoCard: widget.bingoCard)
            }
        }
        .navigationTitle("\(widget.type.toString()) widget")
    }
}
