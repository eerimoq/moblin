import SwiftUI

struct RemoveBackgroundEffectView: View {
    let model: Model
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var removeBackground: SettingsVideoEffectRemoveBackground

    private func updateWidget() {
        model.removeBackgroundEffectSettingsChanged(widget: widget, effect: effect)
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
