import SwiftUI

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
                case .shape:
                    ShapeEffectView(
                        model: model,
                        widgetId: widgetId,
                        effectIndex: effectIndex,
                        shape: effect.shape
                    )
                case .removeBackground:
                    RemoveBackgroundEffectView(
                        widgetId: widgetId,
                        effectIndex: effectIndex,
                        removeBackground: effect.removeBackground
                    )
                case .dewarp360:
                    Dewarp360EffectView(
                        widgetId: widgetId,
                        effectIndex: effectIndex,
                        dewarp360: effect.dewarp360
                    )
                case .anamorphicLens:
                    AnamorphicLensEffectView(
                        widgetId: widgetId,
                        effectIndex: effectIndex,
                        anamorphicLens: effect.anamorphicLens
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
            .onMove { froms, to in
                widget.effects.move(fromOffsets: froms, toOffset: to)
                model.resetSelectedScene(changeScene: false)
            }
            .onDelete { offsets in
                widget.effects.remove(atOffsets: offsets)
                model.resetSelectedScene(changeScene: false)
            }
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
