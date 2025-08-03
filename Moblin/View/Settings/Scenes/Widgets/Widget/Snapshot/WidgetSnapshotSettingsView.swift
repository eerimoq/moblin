import SwiftUI

struct WidgetSnapshotSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @ObservedObject var snapshot: SettingsWidgetSnapshot

    private func setEffectSettings() {
        model.getSnapshotEffect(id: widget.id)?.setSettings(showtime: snapshot.showtime)
    }

    var body: some View {
        Section {
            Picker(selection: $snapshot.showtime) {
                ForEach([3, 5, 10, 15, 30, 60, 120], id: \.self) { showtime in
                    Text("\(showtime)s")
                }
            } label: {
                Text("Showtime")
            }
            .onChange(of: snapshot.showtime) { _ in
                setEffectSettings()
            }
        }
        WidgetEffectsView(widget: widget)
    }
}
