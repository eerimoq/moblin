import SwiftUI

struct WidgetVTuberSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    var body: some View {
        Section {
            Text("VTuber")
        }
    }
}
