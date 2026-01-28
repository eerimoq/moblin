import SwiftUI

struct AnamorphicLensEffectView: View {
    let model: Model
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var anamorphicLens: SettingsVideoEffectAnamorphicLens

    private func updateWidget() {
        model.getWidgetAnamorphicLensEffect(widget, effect)?.setSettings(settings: anamorphicLens.clone())
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
