import SwiftUI

struct AnamorphicLensEffectView: View {
    @EnvironmentObject var model: Model
    let widgetId: UUID
    let effectIndex: Int?
    @ObservedObject var anamorphicLens: SettingsVideoEffectAnamorphicLens

    private func updateWidget() {
        guard let effectIndex, let effect = model.getEffectWithPossibleEffects(id: widgetId) else {
            return
        }
        guard effectIndex < effect.effects.count else {
            return
        }
        guard let effect = effect.effects[effectIndex] as? AnamorphicLensEffect else {
            return
        }
        effect.setSettings(settings: anamorphicLens.clone())
    }

    private func changeScale(value: String) -> String? {
        guard let scale = Double(value) else {
            return String(localized: "Not a number")
        }
        guard scale > 0 else {
            return String(localized: "Too small")
        }
        guard scale <= 10 else {
            return String(localized: "Too big")
        }
        return nil
    }

    private func submitScale(value: String) {
        guard let scale = Double(value) else {
            return
        }
        anamorphicLens.scale = scale
        updateWidget()
    }

    var body: some View {
        Section {
            TextEditNavigationView(title: String(localized: "Desqueeze factor"),
                                   value: String(anamorphicLens.scale),
                                   onChange: changeScale,
                                   onSubmit: submitScale,
                                   valueFormat: { "\($0)x" })
        }
    }
}
