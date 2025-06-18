import SwiftUI

struct WidgetBrowserSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @ObservedObject var browser: SettingsWidgetBrowser

    private func submitUrl(value: String) {
        guard URL(string: value.trim()) != nil else {
            return
        }
        browser.url = value.trim()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitStyleSheet(value: String) {
        browser.styleSheet = value.trim()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        guard width > 0, width < 4000 else {
            return
        }
        browser.width = width
        model.resetSelectedScene(changeScene: false)
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        guard height > 0, height < 4000 else {
            return
        }
        browser.height = height
        model.resetSelectedScene(changeScene: false)
    }

    private func submitFps(value: Float) {
        browser.fps = value
        model.resetSelectedScene(changeScene: false)
    }

    private func formatFps(value: Float) -> String {
        return formatOneDecimal(value)
    }

    var body: some View {
        Section {
            TextEditNavigationView(title: "URL", value: browser.url, onSubmit: submitUrl)
            TextEditNavigationView(
                title: "Style sheet",
                value: browser.styleSheet,
                onSubmit: submitStyleSheet
            )
            Toggle("Audio only", isOn: $browser.audioOnly)
                .onChange(of: browser.audioOnly) { _ in
                    model.resetSelectedScene(changeScene: false)
                }
            if !browser.audioOnly {
                TextEditNavigationView(
                    title: String(localized: "Width"),
                    value: String(browser.width),
                    onSubmit: submitWidth,
                    keyboardType: .numbersAndPunctuation
                )
                TextEditNavigationView(title: String(localized: "Height"),
                                       value: String(browser.height),
                                       onSubmit: submitHeight,
                                       keyboardType: .numbersAndPunctuation)
                Toggle("Scale to fit video width", isOn: $browser.scaleToFitVideo)
                    .onChange(of: browser.scaleToFitVideo) { _ in
                        model.resetSelectedScene(changeScene: false)
                    }
                HStack {
                    Text("FPS")
                    SliderView(
                        value: browser.fps,
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
        Section {
            Toggle("Moblin access", isOn: $browser.moblinAccess)
                .onChange(of: browser.moblinAccess) { _ in
                    model.resetSelectedScene(changeScene: false)
                }
        } footer: {
            Text("Give the webpage access to various data in Moblin, for example chat messages and your location.")
        }
        WidgetEffectsView(widget: widget)
    }
}
