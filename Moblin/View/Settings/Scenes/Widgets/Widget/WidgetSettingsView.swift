import CoreMedia
import SwiftUI

private struct AlignmentOptionView: View {
    @Binding var layout: SettingsWidgetLayout
    let alignment: SettingsAlignment

    var body: some View {
        Button {
            layout.alignment = alignment
        } label: {
            Image(systemName: layout.alignment == alignment ? "square.fill" : "square")
        }
        .buttonStyle(.borderless)
        .font(.title)
    }
}

private struct SceneSettings: Codable {
    let x: Double
    let y: Double
    let size: Double
    let alignment: SettingsAlignment
}

private struct SaveLoadLayoutView: View {
    @EnvironmentObject private var model: Model
    @Binding var layout: SettingsWidgetLayout
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            Button {
                model.layout = layout
            } label: {
                HCenter {
                    Text("Save layout")
                }
            }
            .buttonStyle(.bordered)
            Spacer()
            Button {
                layout = model.layout ?? layout
                model.sceneUpdated()
            } label: {
                HStack {
                    Text("")
                    Spacer(minLength: 0)
                    Text("Load layout")
                    Spacer(minLength: 0)
                    Text("")
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.layout == nil)
            Spacer()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

struct WidgetLayoutView: View {
    let model: Model
    @ObservedObject var database: Database
    @Binding var layout: SettingsWidgetLayout
    @ObservedObject var widget: SettingsWidget
    @Binding var numericInput: Bool

    private func dimensions() -> CMVideoDimensions {
        return model.stream.resolution.dimensions(portrait: model.stream.portrait)
    }

    private func horizontalIncrement() -> Double {
        return 100 / Double(dimensions().width)
    }

    private func verticalIncrement() -> Double {
        return 100 / Double(dimensions().height)
    }

    var body: some View {
        if widget.hasPosition() || widget.hasSize() || widget.hasAlignment() {
            Section {
                if widget.hasAlignment() {
                    HStack {
                        HStack {
                            SaveLoadLayoutView(layout: $layout, widget: widget)
                            Spacer()
                        }
                        Divider()
                        VStack(spacing: 5) {
                            HStack(spacing: 3) {
                                AlignmentOptionView(layout: $layout, alignment: .topLeft)
                                AlignmentOptionView(layout: $layout, alignment: .topCenter)
                                AlignmentOptionView(layout: $layout, alignment: .topRight)
                            }
                            HStack(spacing: 3) {
                                AlignmentOptionView(layout: $layout, alignment: .leftCenter)
                                AlignmentOptionView(layout: $layout, alignment: .center)
                                AlignmentOptionView(layout: $layout, alignment: .rightCenter)
                            }
                            HStack(spacing: 3) {
                                AlignmentOptionView(layout: $layout, alignment: .bottomLeft)
                                AlignmentOptionView(layout: $layout, alignment: .bottomCenter)
                                AlignmentOptionView(layout: $layout, alignment: .bottomRight)
                            }
                        }
                        .onChange(of: layout.alignment) { _ in
                            model.sceneUpdated()
                        }
                    }
                }
                if widget.hasPosition() {
                    if !layout.alignment.isHorizontalCenter() {
                        PositionEditView(
                            number: $layout.x,
                            value: $layout.xString,
                            onSubmit: {
                                model.sceneUpdated()
                            },
                            numericInput: $numericInput,
                            incrementImageName: "arrow.forward.circle",
                            decrementImageName: "arrow.backward.circle",
                            mirror: layout.alignment.mirrorPositionHorizontally(),
                            increment: horizontalIncrement()
                        )
                    }
                    if !layout.alignment.isVerticalCenter() {
                        PositionEditView(
                            number: $layout.y,
                            value: $layout.yString,
                            onSubmit: {
                                model.sceneUpdated()
                            },
                            numericInput: $numericInput,
                            incrementImageName: "arrow.down.circle",
                            decrementImageName: "arrow.up.circle",
                            mirror: layout.alignment.mirrorPositionVertically(),
                            increment: verticalIncrement()
                        )
                    }
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
                Toggle("Numeric input", isOn: $database.sceneNumericInput)
            } header: {
                Text("Layout")
            } footer: {
                Text("""
                Use save/load layout to position a widget in the same place in multiple \
                scenes. Alternatively, use a Scene widget to easily show the same widgets \
                in multiple scenes.
                """)
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
