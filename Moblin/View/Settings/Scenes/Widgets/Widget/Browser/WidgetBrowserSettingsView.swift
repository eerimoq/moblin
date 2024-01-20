import SwiftUI

struct WidgetBrowserSettingsView: View {
    var widget: SettingsWidget

    var body: some View {
        Section {
            // Dismiss when hitting done. Use other view.
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
