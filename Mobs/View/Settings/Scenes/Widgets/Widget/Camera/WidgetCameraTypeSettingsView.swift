import SwiftUI

struct WidgetCameraTypeSettingsView: View {
    @ObservedObject var model: Model
    private var widget: SettingsWidget
    @State private var selection: String

    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        selection = widget.camera.type.rawValue
    }

    var body: some View {
        Form {
            Picker("", selection: $selection) {
                ForEach(cameraTypes, id: \.self) { type in
                    Text(type)
                }
            }
            .onChange(of: selection) { type in
                widget.camera.type = SettingsWidgetCameraType(rawValue: type)!
                model.store()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Type")
    }
}
