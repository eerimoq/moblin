import SwiftUI

var videoEffects = ["Movie", "Gray scale"]

struct WidgetVideoEffectSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State private var selection: String
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        self.selection = widget.videoEffect.type
    }
    
    var body: some View {
        Form {
            Picker("", selection: $selection) {
                ForEach(videoEffects, id: \.self) { videoEffect in
                    Text(videoEffect)
                }
            }
            .onChange(of: selection) { direction in
                widget.camera.direction = direction
                model.store()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Direction")
    }
}
