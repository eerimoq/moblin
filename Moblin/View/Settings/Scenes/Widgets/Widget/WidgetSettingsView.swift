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
                EmptyView()
            case .browser:
                WidgetBrowserSettingsView(widget: widget)
            case .text:
                WidgetTextSettingsView(widget: widget)
            case .crop:
                WidgetCropSettingsView(widget: widget)
            case .map:
                WidgetMapSettingsView(widget: widget)
            case .scene:
                WidgetSceneSettingsView(widget: widget, selectedSceneId: widget.scene!.sceneId)
            }
        }
        .navigationTitle("Widget")
        .toolbar {
            SettingsToolbar()
        }
    }
}
