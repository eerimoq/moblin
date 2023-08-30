import SwiftUI

struct WidgetSettingsView: View {
    var index: Int
    @ObservedObject var model: Model

    var widget: SettingsWidget {
        get {
            model.settings.database.widgets[index]
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    widget.name
                }, set: { value in
                    widget.name = value.trim()
                    model.store()
                    model.numberOfWidgets += 0
                }))
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    widget.type
                }, set: { value in
                    widget.type = value.trim()
                    model.store()
                    model.numberOfWidgets += 0
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
                Section("Format string") {
                    TextField("", text: Binding(get: {
                        widget.text.formatString
                    }, set: { value in
                        widget.text.formatString = value.trim()
                        model.store()
                    }))
                }
            case "Image":
                Section("URL") {
                    TextField("", text: Binding(get: {
                        widget.image.url
                    }, set: { value in
                        widget.image.url = value.trim()
                        model.store()
                    }))
                }
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
                Section("Direction") {
                    TextField("", text: Binding(get: {
                        widget.camera.direction
                    }, set: { value in
                        widget.camera.direction = value.trim()
                        model.store()
                    }))
                }
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

struct WidgetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetSettingsView(index: 0, model: Model())
    }
}
