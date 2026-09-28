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
                Toggle("External camera video range", isOn: $debug.externalCameraVideoRange)
                    .onChange(of: debug.externalCameraVideoRange) { _ in
                        model.setExternalCameraVideoRange()
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
