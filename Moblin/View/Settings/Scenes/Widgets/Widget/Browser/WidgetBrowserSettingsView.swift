import SwiftUI

struct WidgetBrowserSettingsView: View {
    var widget: SettingsWidget

    var body: some View {
        Section {
            NavigationLink(destination: WidgetBrowserUrlSettingsView(
                widget: widget,
                value: widget.browser.url
            )) {
                TextItemView(name: "URL", value: widget.browser.url)
            }
        } header: {
            Text("Browser")
        }
    }
}
