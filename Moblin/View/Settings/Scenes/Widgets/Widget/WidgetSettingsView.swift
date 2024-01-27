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
            Section {
                NavigationLink(destination: NameEditView(
                    name: widget.name,
                    onSubmit: submitName
                )) {
                    TextItemView(name: String(localized: "Name"), value: widget.name)
                }
                HStack {
                    Text("Type")
                    Spacer()
                    Picker("", selection: Binding(get: {
                        widget.type.toString()
                    }, set: { value in
                        widget.type = SettingsWidgetType.fromString(value: value)
                        model.store()
                        model.resetSelectedScene()
                    })) {
                        ForEach(widgetTypes, id: \.self) {
                            Text($0)
                        }
                    }
                }
            }
            switch widget.type {
            case .image:
                WidgetImageSettingsView(widget: widget)
            case .videoEffect:
                WidgetVideoEffectSettingsView(widget: widget,
                                              selection: widget.videoEffect.type.toString(),
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
        .toolbar {
            SettingsToolbar()
        }
    }
}
