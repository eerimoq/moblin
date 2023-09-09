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
            case "Image":
                WidgetImageSettingsView(model: model, widget: widget)
            case "Video effect":
                WidgetVideoEffectSettingsView(model: model, widget: widget)
            case "Camera":
                WidgetCameraSettingsView(model: model, widget: widget)
            default:
                EmptyView()
            }
        }
        .navigationTitle("Widget")
    }
}
