import SwiftUI

struct WidgetBrowserSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    private func submitUrl(value: String) {
        guard URL(string: value.trim()) != nil else {
            return
        }
        widget.browser.url = value.trim()
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        widget.browser.width = width
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        widget.browser.height = height
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitFps(value: Float) {
        widget.browser.fps = value
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func formatFps(value: Float) -> String {
        return formatOneDecimal(value: value)
    }

    var body: some View {
        Section {
            NavigationLink(destination: TextEditView(
                title: "URL",
                value: widget.browser.url,
                onSubmit: submitUrl
            )) {
                TextItemView(name: "URL", value: widget.browser.url)
            }
            Toggle(isOn: Binding(get: {
                widget.browser.audioOnly!
            }, set: { value in
                widget.browser.audioOnly = value
                model.store()
                model.resetSelectedScene(changeScene: false)
            })) {
                Text("Audio only")
            }
            if !widget.browser.audioOnly! {
                NavigationLink(destination: TextEditView(
                    title: "Width",
                    value: String(widget.browser.width),
                    onSubmit: submitWidth
                )) {
                    TextItemView(name: "Width", value: String(widget.browser.width))
                }
                NavigationLink(destination: TextEditView(
                    title: "Height",
                    value: String(widget.browser.height),
                    onSubmit: submitHeight
                )) {
                    TextItemView(name: "Height", value: String(widget.browser.height))
                }
                Toggle(isOn: Binding(get: {
                    widget.browser.scaleToFitVideo!
                }, set: { value in
                    widget.browser.scaleToFitVideo = value
                    model.store()
                    model.resetSelectedScene(changeScene: false)
                })) {
                    Text("Scale to fit video")
                }
                HStack {
                    Text("FPS")
                    SliderView(
                        value: widget.browser.fps!,
                        minimum: 0.5,
                        maximum: 5,
                        step: 0.5,
                        onSubmit: submitFps,
                        width: 60,
                        format: formatFps
                    )
                }
            }
        } header: {
            Text("Browser")
        }
    }
}
