import SwiftUI

struct WatchLocalOverlaysSettingsView: View {
    @EnvironmentObject var model: Model

    var show: WatchSettingsShow {
        model.database.watch!.show!
    }

    var body: some View {
        Form {
            Section {
                Toggle("Thermal state", isOn: Binding(get: {
                    show.thermalState
                }, set: { value in
                    show.thermalState = value
                    model.sendSettingsToWatch()
                }))
                Toggle("Audio level", isOn: Binding(get: {
                    show.audioLevel
                }, set: { value in
                    show.audioLevel = value
                    model.sendSettingsToWatch()
                }))
                Toggle("Bitrate", isOn: Binding(get: {
                    show.speed
                }, set: { value in
                    show.speed = value
                    model.sendSettingsToWatch()
                }))
            }
        }
        .navigationTitle("Local overlays")
        .toolbar {
            SettingsToolbar()
        }
    }
}
