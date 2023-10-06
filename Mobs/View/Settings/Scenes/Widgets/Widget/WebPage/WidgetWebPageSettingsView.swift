import SwiftUI

struct WidgetWebPageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget

    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
    }

    var body: some View {
        Section("Web page") {
            NavigationLink(destination: WidgetWebPageUrlSettingsView(
                model: model,
                widget: widget
            )) {
                TextItemView(name: "URL", value: widget.webPage!.url)
            }
        }
    }
}
