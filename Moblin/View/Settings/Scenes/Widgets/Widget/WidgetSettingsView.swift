import SwiftUI

private struct RemoveBackgroundView: View {
    @EnvironmentObject var model: Model
    let widgetId: UUID
    let effectIndex: Int?
    @ObservedObject var removeBackground: SettingsVideoEffectRemoveBackground

    private func updateWidget() {
        guard let effectIndex, let effect = model.getEffectWithPossibleEffects(id: widgetId) else {
            return
        }
        guard effectIndex < effect.effects.count else {
            return
        }
        guard let effect = effect.effects[effectIndex] as? RemoveBackgroundEffect else {
            return
        }
        effect.setColorRange(from: removeBackground.from, to: removeBackground.to)
    }

    var body: some View {
        Section {
            ColorPicker("From", selection: $removeBackground.fromColor, supportsOpacity: false)
                .onChange(of: removeBackground.fromColor) { _ in
                    guard let color = removeBackground.fromColor.toRgb() else {
                        return
                    }
                    removeBackground.from = color
                    updateWidget()
                }
            ColorPicker("To", selection: $removeBackground.toColor, supportsOpacity: false)
                .onChange(of: removeBackground.toColor) { _ in
                    guard let color = removeBackground.toColor.toRgb() else {
                        return
                    }
                    removeBackground.to = color
                    updateWidget()
                }
        } header: {
            Text("Color range")
        }
    }
}

private struct ShapeView: View {
    @EnvironmentObject var model: Model
    let widgetId: UUID
    let effectIndex: Int?
    @ObservedObject var shape: SettingsVideoEffectShape

    private func updateWidget() {
        guard let effectIndex, let effect = model.getEffectWithPossibleEffects(id: widgetId) else {
            return
        }
        guard effectIndex < effect.effects.count else {
            return
        }
        guard let effect = effect.effects[effectIndex] as? ShapeEffect else {
            return
        }
        effect.setSettings(settings: shape.toSettings())
    }

    var body: some View {
        Section {
            HStack {
                Slider(
                    value: $shape.cornerRadius,
                    in: 0 ... 1,
                    step: 0.01
                )
                .onChange(of: shape.cornerRadius) { _ in
                    updateWidget()
                }
                Text(String(Int(shape.cornerRadius * 100)))
                    .frame(width: 35)
            }
        } header: {
            Text("Corner radius")
        }
        Section {
            HStack {
                Text("Width")
                Slider(
                    value: $shape.borderWidth,
                    in: 0 ... 1.0,
                    step: 0.01
                )
                .onChange(of: shape.borderWidth) { _ in
                    updateWidget()
                }
            }
            ColorPicker("Color", selection: $shape.borderColorColor, supportsOpacity: false)
                .onChange(of: shape.borderColorColor) { _ in
                    guard let borderColor = shape.borderColorColor.toRgb() else {
                        return
                    }
                    shape.borderColor = borderColor
                    updateWidget()
                }
        } header: {
            Text("Border")
        }
    }
}

private struct EffectView: View {
    @EnvironmentObject var model: Model
    let widgetId: UUID
    let effectIndex: Int?
    @ObservedObject var effect: SettingsVideoEffect

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Picker("Type", selection: $effect.type) {
                        ForEach(SettingsVideoEffectType.allCases, id: \.self) {
                            Text($0.toString())
                                .tag($0)
                        }
                    }
                    .onChange(of: effect.type) { _ in
                        model.resetSelectedScene(changeScene: false)
                    }
                }
                switch effect.type {
                case .removeBackground:
                    RemoveBackgroundView(
                        widgetId: widgetId,
                        effectIndex: effectIndex,
                        removeBackground: effect.removeBackground
                    )
                case .shape:
                    ShapeView(
                        widgetId: widgetId,
                        effectIndex: effectIndex,
                        shape: effect.shape
                    )
                default:
                    EmptyView()
                }
            }
            .navigationTitle(effect.type.toString())
        } label: {
            HStack {
                DraggableItemPrefixView()
                Toggle(effect.type.toString(), isOn: $effect.enabled)
                    .onChange(of: effect.enabled) { _ in
                        model.resetSelectedScene(changeScene: false)
                    }
            }
        }
    }
}

struct WidgetEffectsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Section {
            ForEach(widget.effects) { effect in
                EffectView(
                    widgetId: widget.id,
                    effectIndex: widget.effects.filter { $0.enabled }.firstIndex(where: { $0 === effect }),
                    effect: effect
                )
            }
            .onMove(perform: { froms, to in
                widget.effects.move(fromOffsets: froms, toOffset: to)
                model.resetSelectedScene(changeScene: false)
            })
            .onDelete(perform: { offsets in
                widget.effects.remove(atOffsets: offsets)
                model.resetSelectedScene(changeScene: false)
            })
            AddButtonView {
                widget.effects.append(SettingsVideoEffect())
                model.resetSelectedScene(changeScene: false)
            }
        } header: {
            Text("Effects")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "an effect"))
        }
    }
}

struct WidgetSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    NameEditView(name: $widget.name)
                } label: {
                    TextItemView(name: String(localized: "Name"), value: widget.name)
                }
                NavigationLink {
                    InlinePickerView(title: String(localized: "Type"),
                                     onChange: { id in
                                         widget.type = SettingsWidgetType(rawValue: id) ?? .browser
                                         model.resetSelectedScene(changeScene: false)
                                     },
                                     items: widgetTypes.map { .init(id: $0.rawValue, text: $0.toString()) },
                                     selectedId: widget.type.rawValue)
                } label: {
                    TextItemView(
                        name: String(localized: "Type"),
                        value: widget.type.toString()
                    )
                }
            }
            switch widget.type {
            case .image:
                WidgetImageSettingsView(widget: widget)
            case .videoEffect:
                EmptyView()
            case .browser:
                WidgetBrowserSettingsView(widget: widget, browser: widget.browser)
            case .text:
                WidgetTextSettingsView(widget: widget, text: widget.text)
            case .crop:
                WidgetCropSettingsView(widget: widget)
            case .map:
                WidgetMapSettingsView(widget: widget, delay: widget.map.delay!)
            case .scene:
                WidgetSceneSettingsView(widget: widget, selectedSceneId: widget.scene.sceneId)
            case .qrCode:
                WidgetQrCodeSettingsView(widget: widget)
            case .alerts:
                WidgetAlertsSettingsView(widget: widget)
            case .videoSource:
                WidgetVideoSourceSettingsView(widget: widget, videoSource: widget.videoSource)
            case .scoreboard:
                WidgetScoreboardSettingsView(widget: widget, type: widget.scoreboard.type)
            case .vTuber:
                WidgetVTuberSettingsView(widget: widget, vTuber: widget.vTuber)
            case .pngTuber:
                WidgetPngTuberSettingsView(widget: widget, pngTuber: widget.pngTuber)
            }
        }
        .navigationTitle("Widget")
    }
}
