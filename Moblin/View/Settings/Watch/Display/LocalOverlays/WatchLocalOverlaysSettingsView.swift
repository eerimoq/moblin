import SwiftUI

struct WatchLocalOverlaysSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var show: WatchSettingsShow

    var body: some View {
        Form {
            Section {
                Toggle("Thermal state", isOn: $show.thermalState)
                    .onChange(of: show.thermalState) { _ in
                        model.sendSettingsToWatch()
                    }
                Toggle("Audio level", isOn: $show.audioLevel)
                    .onChange(of: show.audioLevel) { _ in
                        model.sendSettingsToWatch()
                    }
                Toggle("Bitrate", isOn: $show.speed)
                    .onChange(of: show.speed) { _ in
                        model.sendSettingsToWatch()
                    }
            }
        }
        .navigationTitle("Local overlays")
    }
}
