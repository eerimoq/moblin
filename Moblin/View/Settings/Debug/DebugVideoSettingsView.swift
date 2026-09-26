import SwiftUI

struct DebugVideoSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debug: SettingsDebug

    var body: some View {
        Form {
            Section {
                Toggle("Native low light boost", isOn: $debug.nativeLowLightBoost)
                    .onChange(of: debug.nativeLowLightBoost) { _ in
                        model.setNativeLowLightBoost()
                    }
            } footer: {
                Text("Change camera and restart stream for these to work properly.")
            }
            Section {
                Toggle("Periodic video bitrate change", isOn: $debug.videoBitrateChange)
            }
        }
        .navigationTitle("Video")
    }
}
