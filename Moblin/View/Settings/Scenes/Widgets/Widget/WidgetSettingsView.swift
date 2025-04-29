import SwiftUI

struct WidgetSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var type: String
    @State var name: String

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    NameEditView(name: $name)
                } label: {
                    TextItemView(name: String(localized: "Name"), value: name)
                }
                .onChange(of: name) { name in
                    widget.name = name
                }
                NavigationLink {
                    InlinePickerView(title: String(localized: "Type"),
                                     onChange: { id in
                                         widget.type = SettingsWidgetType(rawValue: id) ?? .browser
                                         model.resetSelectedScene(changeScene: false)
                                     },
                                     items: widgetTypes.map { .init(
                                         id: SettingsWidgetType.fromString(value: $0).rawValue,
                                         text: $0
                                     ) },
                                     selectedId: widget.type.rawValue)
                } label: {
                    TextItemView(
                        name: String(localized: "Type"),
                        value: widget.type.toString()
                    )
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
                                       horizontalAlignment: widget.text.horizontalAlignment!.toString(),
                                       verticalAlignment: widget.text.verticalAlignment!.toString(),
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
            case .videoSource:
                WidgetVideoSourceSettingsView(widget: widget,
                                              cornerRadius: widget.videoSource!.cornerRadius,
                                              selectedRotation: widget.videoSource!.rotation!,
                                              zoom: widget.videoSource!.trackFaceZoom!,
                                              borderWidth: widget.videoSource!.borderWidth!,
                                              background: widget.videoSource!.borderColor!.color())
            case .scoreboard:
                WidgetScoreboardSettingsView(widget: widget, type: widget.scoreboard!.type.rawValue)
            }
        }
        .navigationTitle("Widget")
    }
}
