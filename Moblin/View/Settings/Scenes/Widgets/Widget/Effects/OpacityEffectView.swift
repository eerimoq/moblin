import SwiftUI

struct OpacityEffectView: View {
    let model: Model
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var opacity: SettingsVideoEffectOpacity

    private func updateWidget() {
        model.getWidgetOpacityEffect(widget, effect)?.setOpacity(opacity: opacity.opacity)
    }

    var body: some View {
        Section {
            Slider(value: $opacity.opacity, in: 0 ... 1)
                .onChange(of: opacity.opacity) { _ in
                    updateWidget()
                }
        }
    }
}
