import SwiftUI

struct RemoveBackgroundEffectView: View {
    @EnvironmentObject var model: Model
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
