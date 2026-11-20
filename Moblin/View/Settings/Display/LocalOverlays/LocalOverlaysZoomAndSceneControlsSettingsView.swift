import SwiftUI

struct LocalOverlaysZoomAndSceneControlsSettingsView: View {
    @ObservedObject var database: Database
    @ObservedObject var show: SettingsShow

    var body: some View {
        Form {
            Section {
                Picker("Layout", selection: $database.zoomAndSceneButtonsLayout) {
                    ForEach(SettingsZoomAndSceneButtonsLayout.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                Toggle("Big buttons", isOn: $database.bigButtons)
            } header: {
                Text("General")
            } footer: {
                Text("The layout is only used in landscape.")
            }
            if database.showAllSettings {
                Section {
                    Toggle("Buttons", isOn: $show.zoomPresets)
                    Toggle("Slider", isOn: $show.zoomSlider)
                } header: {
                    Text("Zoom")
                }
            }
        }
        .navigationTitle("Zoom and scene controls")
    }
}
