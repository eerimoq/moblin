import SwiftUI

struct WidgetBrowserSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    private func submitUrl(value: String) {
        guard let url = URL(string: value.trim()) else {
            return
        }
        widget.browser.url = value.trim()
        model.store()
        model.resetSelectedScene()
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        widget.browser.width = width
        model.store()
        model.resetSelectedScene()
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        widget.browser.height = height
        model.store()
        model.resetSelectedScene()
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
        } header: {
            Text("Browser")
        }
    }
}
