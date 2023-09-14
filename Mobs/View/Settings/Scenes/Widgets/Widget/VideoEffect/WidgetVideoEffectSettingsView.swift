import SwiftUI

struct WidgetVideoEffectSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    @State private var selection: String

    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        selection = widget.videoEffect.type.rawValue
    }

    var body: some View {
        Section("Video effect") {
            Picker("", selection: $selection) {
                ForEach(videoEffects, id: \.self) { videoEffect in
                    Text(videoEffect)
                }
            }
            .onChange(of: selection) { type in
                widget.videoEffect.type = SettingsWidgetVideoEffectType(rawValue: type)!
                model.sceneUpdated()
                model.store()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Video effect")
    }
}
