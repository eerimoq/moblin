import SwiftUI

struct WidgetCameraSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    
    var body: some View {
        Section(widget.type.rawValue) {
            NavigationLink(destination: WidgetCameraTypeSettingsView(model: model, widget: widget)) {
                TextItemView(name: "Type", value: widget.camera.type.rawValue)
            }
        }
    }
}
