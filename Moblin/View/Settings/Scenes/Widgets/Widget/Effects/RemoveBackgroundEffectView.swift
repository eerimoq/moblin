import SwiftUI

struct RemoveBackgroundEffectView: View {
    let model: Model
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var removeBackground: SettingsVideoEffectRemoveBackground

    private func updateWidget() {
        model.getWidgetRemoveBackgroundEffect(widget, effect)?.setColorRange(
            from: removeBackground.from,
            to: removeBackground.to
        )
    }

    var body: some View {
        Section {
            RgbColorPickerView(title: "From", color: $removeBackground.fromColor) {
                removeBackground.from = $0
                updateWidget()
            }
            RgbColorPickerView(title: "To", color: $removeBackground.toColor) {
                removeBackground.to = $0
                updateWidget()
            }
        } header: {
            Text("Color range")
        }
    }
}
