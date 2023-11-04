import SwiftUI

struct DebugSettingsView: View {
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
            }
        }
        .navigationTitle("Debug")
    }
}
