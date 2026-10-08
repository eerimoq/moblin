import SwiftUI

struct DebugVideoSettingsView: View {
    let model: Model
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
            Section {
                Picker(selection: $debug.photosImageQuality) {
                    ForEach([0.9, 0.95, 1.0], id: \.self) { quality in
                        Text(String(quality))
                    }
                } label: {
                    Text("Photos image quality")
                }
                .onChange(of: debug.photosImageQuality) { _ in
                    model.setPhotosImageQuality()
                }
            } footer: {
                Text("Compression quality of snapshots and photo shoot photos saved to Photos.")
            }
        }
        .navigationTitle("Video")
    }
}
