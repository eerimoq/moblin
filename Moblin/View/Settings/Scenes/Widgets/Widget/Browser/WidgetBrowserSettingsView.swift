import SwiftUI

struct WidgetBrowserSettingsView: View {
    var widget: SettingsWidget

    /* func submitWidth(value: String) {
         if let width = Int(value.trim()) {
             widget.browser!.width = width
             model.store()
         }
     }

     func submitHeight(value: String) {
         if let height = Int(value.trim()) {
             widget.browser!.height = height
             model.store()
         }
     }

     func submitCustomCSS(value: String) {
         widget.browser!.customCss = value
         model.store()
     } */

    var body: some View {
        Section {
            NavigationLink(destination: WidgetBrowserUrlSettingsView(
                widget: widget,
                value: widget.browser.url
            )) {
                TextItemView(name: "URL", value: widget.browser.url)
            }
            /* NavigationLink(destination: TextEditView(
              title: "Width",
              value: String(widget.browser!.width),
              onSubmit: submitWidth
              )) {
              TextItemView(name: "Width", value: String(widget.browser!.width))
              }
              NavigationLink(destination: TextEditView(
              title: "Height",
              value: String(widget.browser!.height),
              onSubmit: submitHeight
              )) {
              TextItemView(name: "Height", value: String(widget.browser!.height))
              }
             NavigationLink(destination: TextEditView(
                 title: "Custom CSS",
                 value: widget.browser!.customCss,
                 onSubmit: submitCustomCSS
             )) {
                 TextItemView(name: "Custom CSS", value: widget.browser!.customCss)
             } */
        } header: {
            Text("Browser")
        }
    }
}
