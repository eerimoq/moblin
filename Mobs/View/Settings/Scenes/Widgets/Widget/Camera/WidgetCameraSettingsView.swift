import SwiftUI

struct WidgetCameraSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    
    var body: some View {
        Section(widget.type.rawValue) {
            NavigationLink(destination: WidgetCameraDirectionSettingsView(model: model, widget: widget)) {
                TextItemView(name: "Direction", value: widget.camera.direction)
            }
        }
    }
}
