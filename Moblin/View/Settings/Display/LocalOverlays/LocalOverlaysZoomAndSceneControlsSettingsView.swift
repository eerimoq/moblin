import SwiftUI

struct LocalOverlaysZoomAndSceneControlsSettingsView: View {
    @ObservedObject var database: Database
    @ObservedObject var show: SettingsShow

    var body: some View {
        Form {
            Section {
                Toggle("Big buttons", isOn: $database.bigButtons)
                Toggle("Zoom and scene buttons on one row", isOn: $database.zoomAndSceneButtonsOnOneRow)
                    .disabled(database.verticalSceneButtons || database.verticalZoomButtons)
            } header: {
                Text("General")
            }
            Section {
                if database.showAllSettings {
                    Toggle("Buttons", isOn: $show.zoomPresets)
                    Toggle("Slider", isOn: $show.zoomSlider)
                }
                Toggle("Vertical buttons", isOn: $database.verticalZoomButtons)
            } header: {
                Text("Zoom")
            }
            Section {
                Toggle("Vertical buttons", isOn: $database.verticalSceneButtons)
            } header: {
                Text("Scene")
            }
        }
        .navigationTitle("Zoom and scene controls")
    }
}
