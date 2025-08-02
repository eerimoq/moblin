import SwiftUI

struct WidgetSnapshotSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget

    var body: some View {
        WidgetEffectsView(widget: widget)
    }
}
