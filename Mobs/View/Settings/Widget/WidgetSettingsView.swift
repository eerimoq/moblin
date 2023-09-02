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
            NavigationLink(destination: WidgetNameSettingsView(model: model, widget: widget)) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(widget.name).foregroundColor(.gray)
                }
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
                WidgetTextSettingsView(model: model, widget: widget)
            case "Image":
                WidgetImageSettingsView(model: model, widget: widget)
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
