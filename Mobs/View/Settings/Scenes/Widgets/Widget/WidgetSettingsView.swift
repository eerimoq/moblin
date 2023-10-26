import SwiftUI

struct WidgetSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

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
                WidgetImageSettingsView(widget: widget)
            case .videoEffect:
                WidgetVideoEffectSettingsView(widget: widget,
                                              selection: widget.videoEffect.type.rawValue,
                                              noiseLevel: widget.videoEffect
                                                  .noiseReductionNoiseLevel * 10,
                                              sharpness: widget.videoEffect
                                                  .noiseReductionSharpness / 10)
            case .browser:
                WidgetBrowserSettingsView(widget: widget)
            case .time:
                EmptyView()
            }
        }
        .navigationTitle("Widget")
    }
}
