import SwiftUI

struct WidgetSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var type: String
    @State var name: String

    func submitName(name: String) {
        widget.name = name
        self.name = name
    }

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: NameEditView(name: name, onSubmit: submitName)) {
                    TextItemView(name: String(localized: "Name"), value: name)
                }
                HStack {
                    Text("Type")
                    Spacer()
                    Picker("", selection: $type) {
                        ForEach(widgetTypes, id: \.self) {
                            Text($0)
                        }
                    }
                    .onChange(of: type) {
                        widget.type = SettingsWidgetType.fromString(value: $0)
                        model.resetSelectedScene()
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
                                       fontSize: Float(widget.text.fontSize!),
                                       fontDesign: widget.text.fontDesign!.toString(),
                                       fontWeight: widget.text.fontWeight!.toString(),
                                       delay: widget.text.delay!)
            case .crop:
                WidgetCropSettingsView(widget: widget)
            case .map:
                WidgetMapSettingsView(widget: widget, delay: widget.map!.delay!)
            case .scene:
                WidgetSceneSettingsView(widget: widget, selectedSceneId: widget.scene!.sceneId)
            case .qrCode:
                WidgetQrCodeSettingsView(widget: widget)
            case .alerts:
                WidgetAlertsSettingsView(widget: widget)
            case .video:
                EmptyView()
            }
        }
        .navigationTitle("Widget")
        .toolbar {
            SettingsToolbar()
        }
    }
}
