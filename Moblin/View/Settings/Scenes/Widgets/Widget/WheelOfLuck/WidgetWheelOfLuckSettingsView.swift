import SwiftUI

struct WidgetWheelOfLuckSettingsView: View {
    let model: Model
    let widget: SettingsWidget

    var body: some View {
        Section {
            if let effect = model.getWheelOfLuckEffect(id: widget.id) {
                WheelOfLuckWidgetView(effect: effect, indented: false)
            }
        }
    }
}
