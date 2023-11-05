import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DebugLogSettingsView()) {
                    Text("Log")
                }
                Toggle("Debug", isOn: Binding(get: {
                    logger.debugEnabled
                }, set: { value in
                    logger.debugEnabled = value
                }))
                NavigationLink(destination: DebugAudioSettingsView()) {
                    Text("Audio")
                }
                NavigationLink(
                    destination: DebugAdaptiveBitrateSettingsView(
                        packetsInFlight: Double(model
                            .getAdaptiveBitratePacketsInFlight())
                    )
                ) {
                    Text("Adaptive bitrate")
                }
            }
        }
        .navigationTitle("Debug")
    }
}
