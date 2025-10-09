import SwiftUI

struct ShapeView: View {
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
