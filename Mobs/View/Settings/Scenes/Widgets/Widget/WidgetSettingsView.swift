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
            NavigationLink(destination: NameEditView(
                name: widget.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: widget.name)
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    widget.type.rawValue
                }, set: { value in
                    widget.type = SettingsWidgetType(rawValue: value)!
                    model.store()
                    model.resetSelectedScene()
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
            case .image:
                WidgetImageSettingsView(model: model, widget: widget)
            case .videoEffect:
                WidgetVideoEffectSettingsView(model: model, widget: widget)
            case .camera:
                EmptyView()
            }
        }
        .navigationTitle("Widget")
    }
}
