import CoreMedia
import SwiftUI

struct AlignmentOptionView: View {
    let selected: SettingsAlignment
    let alignment: SettingsAlignment
    let onChange: (SettingsAlignment) -> Void

    var body: some View {
        Button {
            onChange(alignment)
        } label: {
            Image(systemName: selected == alignment ? "square.fill" : "square")
        }
        .buttonStyle(.borderless)
        .font(.title)
    }
}

struct AlignmentPickerView: View {
    let alignment: SettingsAlignment
    let onChange: (SettingsAlignment) -> Void

    private func option(_ alignment: SettingsAlignment) -> some View {
        AlignmentOptionView(selected: self.alignment, alignment: alignment, onChange: onChange)
    }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                option(.topLeft)
                option(.topCenter)
                option(.topRight)
            }
            HStack(spacing: 3) {
                option(.leftCenter)
                option(.center)
                option(.rightCenter)
            }
            HStack(spacing: 3) {
                option(.bottomLeft)
                option(.bottomCenter)
                option(.bottomRight)
            }
        }
    }
}

struct CopyLayoutButtonView: View {
    @EnvironmentObject private var model: Model
    @Binding var layout: SettingsWidgetLayout

    var body: some View {
        Button {
            model.layout = layout
        } label: {
            HCenter {
                Text("Copy layout")
            }
        }
        .buttonStyle(.bordered)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

struct PasteLayoutButtonView: View {
    @EnvironmentObject private var model: Model
    @Binding var layout: SettingsWidgetLayout

    var body: some View {
        Button {
            layout = model.layout ?? layout
            model.sceneUpdated()
        } label: {
            HStack {
                Text("")
                Spacer(minLength: 0)
                Text("Paste layout")
                Spacer(minLength: 0)
                Text("")
            }
        }
        .buttonStyle(.bordered)
        .disabled(model.layout == nil)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

struct CopyPasteLayoutView: View {
    @Binding var layout: SettingsWidgetLayout

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            CopyLayoutButtonView(layout: $layout)
            Spacer()
            PasteLayoutButtonView(layout: $layout)
            Spacer()
        }
    }
}

struct WidgetLayoutView: View {
    let model: Model
    @ObservedObject var sceneWidget: SettingsSceneWidget
    @ObservedObject var widget: SettingsWidget
    let size: CGSize

    private var layout: SettingsWidgetLayout {
        sceneWidget.layout
    }

    private func dimensions() -> CMVideoDimensions {
        model.stream.resolution.dimensions(portrait: model.stream.portrait)
    }

    private func width(size: Double) -> Double {
        let dimensions = dimensions()
        return model.sceneEditorWidgetWidth(
            widget: widget,
            layout: layout,
            size: size,
            canvasSize: CGSize(width: Double(dimensions.width), height: Double(dimensions.height))
        )
    }

    private func generalAndAlignmentPicker() -> some View {
        HStack {
            HStack {
                CopyPasteLayoutView(layout: $sceneWidget.layout)
                Spacer()
            }
            Divider()
            AlignmentPickerView(alignment: layout.alignment) { alignment in
                model.sceneEditorSetWidgetAlignment(
                    sceneWidget: sceneWidget,
                    size: size,
                    alignment: alignment
                )
            }
        }
    }

    private func horizontalPositioning() -> some View {
        PositionEditView(
            number: $sceneWidget.layout.x,
            onSubmit: {
                model.sceneUpdatedThrottled()
            },
            incrementImageName: "arrow.forward.circle",
            decrementImageName: "arrow.backward.circle",
            mirror: layout.alignment.mirrorPositionHorizontally(),
            total: Double(dimensions().width)
        )
    }

    private func verticalPositioning() -> some View {
        PositionEditView(
            number: $sceneWidget.layout.y,
            onSubmit: {
                model.sceneUpdatedThrottled()
            },
            incrementImageName: "arrow.down.circle",
            decrementImageName: "arrow.up.circle",
            mirror: layout.alignment.mirrorPositionVertically(),
            total: Double(dimensions().height)
        )
    }

    var body: some View {
        if widget.hasAlignment() || widget.hasPosition() || widget.hasSize() {
            Section {
                if widget.hasAlignment() {
                    generalAndAlignmentPicker()
                } else {
                    HStack {
                        CopyLayoutButtonView(layout: $sceneWidget.layout)
                        PasteLayoutButtonView(layout: $sceneWidget.layout)
                    }
                }
                if widget.hasPosition() {
                    if !layout.alignment.isHorizontalCenter() {
                        horizontalPositioning()
                    }
                    if !layout.alignment.isVerticalCenter() {
                        verticalPositioning()
                    }
                }
                if widget.hasSize() {
                    SizeEditView(
                        number: $sceneWidget.layout.size,
                        zero: width(size: 0),
                        total: width(size: 100),
                        onSubmit: {
                            model.sceneUpdatedThrottled()
                        }
                    )
                }
            } header: {
                Text("Layout")
            } footer: {
                Text("""
                Use copy/paste layout to position a widget in the same place in multiple \
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

struct WidgetSettingsSectionsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget

    var body: some View {
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
            WidgetMapSettingsView(widget: widget, delay: widget.map.delay, size: widget.map.size)
        case .scene:
            WidgetSceneSettingsView(widget: widget, scene: widget.scene)
        case .slideshow:
            WidgetSlideshowSettingsView(widget: widget)
        case .qrCode:
            WidgetQrCodeSettingsView(model: model, widget: widget)
        case .alerts:
            WidgetAlertsSettingsView(model: model, widget: widget)
        case .videoSource:
            WidgetVideoSourceSettingsView(widget: widget,
                                          videoSource: widget.videoSource,
                                          videoSources: model.videoSources)
        case .scoreboard:
            WidgetScoreboardSettingsView(model: model,
                                         widget: widget,
                                         scoreboard: widget.scoreboard,
                                         web: database.remoteControl.web)
        case .vTuber:
            WidgetVTuberSettingsView(model: model,
                                     widget: widget,
                                     vTuber: widget.vTuber,
                                     videoSources: model.videoSources)
        case .pngTuber:
            WidgetPngTuberSettingsView(model: model,
                                       widget: widget,
                                       pngTuber: widget.pngTuber,
                                       videoSources: model.videoSources)
        case .snapshot:
            WidgetSnapshotSettingsView(model: model, widget: widget, snapshot: widget.snapshot)
        case .chat:
            WidgetChatSettingsView(model: model, database: database, widget: widget, chat: widget.chat)
        case .chatEmoteCombo:
            WidgetChatEmoteComboSettingsView(
                model: model,
                widget: widget,
                chatEmoteCombo: widget.chatEmoteCombo
            )
        case .wheelOfLuck:
            WidgetWheelOfLuckSettingsView(model: model, widget: widget, wheelOfLuck: widget.wheelOfLuck)
        case .bingoCard:
            WidgetBingoCardSettingsView(model: model, widget: widget, bingoCard: widget.bingoCard)
        case .pomodoroTimer:
            WidgetPomodoroTimerSettingsView(model: model, pomodoroTimer: widget.pomodoroTimer)
        }
    }
}

struct WidgetSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Form {
            WidgetSettingsSectionsView(model: model, database: database, widget: widget)
        }
        .navigationTitle("\(widget.type.toString()) widget")
    }
}
