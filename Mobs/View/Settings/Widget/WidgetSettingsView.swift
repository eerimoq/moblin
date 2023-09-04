import SwiftUI

struct WidgetSettingsView: View {
    var widget: SettingsWidget
    @ObservedObject var model: Model

    func submitName(name: String) {
        widget.name = name
        model.store()
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(name: widget.name, onSubmit: submitName)) {
                TextItemView(name: "Name", value: widget.name)
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    widget.type
                }, set: { value in
                    widget.type = value.trim()
                    model.store()
                    model.objectWillChange.send()
                })) {
                    ForEach(widgetTypes, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            switch widget.type {
            case "Text":
                WidgetTextSettingsView(model: model, widget: widget)
            case "Image":
                WidgetImageSettingsView(model: model, widget: widget)
            case "Image":
                WidgetVideoEffectSettingsView(model: model, widget: widget)
            case "Video":
                Section("URL") {
                    TextField("", text: Binding(get: {
                        widget.video.url
                    }, set: { value in
                        widget.video.url = value.trim()
                        model.store()
                    }))
                }
            case "Camera":
                WidgetCameraSettingsView(model: model, widget: widget)
            case "Webview":
                Section("URL") {
                    TextField("", text: Binding(get: {
                        widget.webview.url
                    }, set: { value in
                        widget.webview.url = value.trim()
                        model.store()
                    }))
                }
            default:
                EmptyView()
            }
        }
        .navigationTitle("Widget")
    }
}
