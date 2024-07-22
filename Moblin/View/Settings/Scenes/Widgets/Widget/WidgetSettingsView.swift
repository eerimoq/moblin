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
                WidgetTextSettingsView(widget: widget,
                                       backgroundColor: widget.text.backgroundColor!.color(),
                                       foregroundColor: widget.text.foregroundColor!.color(),
                                       fontSize: Float(widget.text.fontSize!), delay: widget.text.delay!)
            case .crop:
                WidgetCropSettingsView(widget: widget)
            case .map:
                WidgetMapSettingsView(widget: widget, delay: widget.map!.delay!)
            case .scene:
                WidgetSceneSettingsView(widget: widget, selectedSceneId: widget.scene!.sceneId)
            case .qrCode:
                WidgetQrCodeSettingsView(widget: widget)
            }
        }
        .navigationTitle("Widget")
        .toolbar {
            SettingsToolbar()
        }
    }
}
