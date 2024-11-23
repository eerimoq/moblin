import SwiftUI

struct WidgetBrowserSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    private func submitUrl(value: String) {
        guard URL(string: value.trim()) != nil else {
            return
        }
        widget.browser.url = value.trim()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitStyleSheet(value: String) {
        widget.browser.styleSheet = value.trim()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        guard width > 0, width < 4000 else {
            return
        }
        widget.browser.width = width
        model.resetSelectedScene(changeScene: false)
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        guard height > 0, height < 4000 else {
            return
        }
        widget.browser.height = height
        model.resetSelectedScene(changeScene: false)
    }

    private func submitFps(value: Float) {
        widget.browser.fps = value
        model.resetSelectedScene(changeScene: false)
    }

    private func formatFps(value: Float) -> String {
        return formatOneDecimal(value)
    }

    var body: some View {
        Section {
            TextEditNavigationView(title: "URL", value: widget.browser.url, onSubmit: submitUrl)
            TextEditNavigationView(
                title: "Style sheet",
                value: widget.browser.styleSheet!,
                onSubmit: submitStyleSheet
            )
            Toggle(isOn: Binding(get: {
                widget.browser.audioOnly!
            }, set: { value in
                widget.browser.audioOnly = value
                model.resetSelectedScene(changeScene: false)
            })) {
                Text("Audio only")
            }
            if !widget.browser.audioOnly! {
                TextEditNavigationView(
                    title: String(localized: "Width"),
                    value: String(widget.browser.width),
                    onSubmit: submitWidth,
                    keyboardType: .numbersAndPunctuation
                )
                TextEditNavigationView(title: String(localized: "Height"),
                                       value: String(widget.browser.height),
                                       onSubmit: submitHeight,
                                       keyboardType: .numbersAndPunctuation)
                Toggle(isOn: Binding(get: {
                    widget.browser.scaleToFitVideo!
                }, set: { value in
                    widget.browser.scaleToFitVideo = value
                    model.resetSelectedScene(changeScene: false)
                })) {
                    Text("Scale to fit video width")
                }
                HStack {
                    Text("FPS")
                    SliderView(
                        value: widget.browser.fps!,
                        minimum: 1,
                        maximum: 15,
                        step: 1,
                        onSubmit: submitFps,
                        width: 60,
                        format: formatFps
                    )
                }
            }
        }
    }
}
