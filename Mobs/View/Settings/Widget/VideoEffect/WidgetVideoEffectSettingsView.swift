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
        print(self.selection, videoEffects)
    }
    
    var body: some View {
        Section(widget.name) {
            Picker("", selection: $selection) {
                ForEach(videoEffects, id: \.self) { videoEffect in
                    Text(videoEffect)
                }
            }
            .onChange(of: selection) { videoEffect in
                widget.videoEffect.type = videoEffect
                model.store()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Video effect")
    }
}
