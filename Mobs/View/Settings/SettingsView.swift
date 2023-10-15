import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamsSettingsView(model: model)) {
                    Text("Streams")
                }
                NavigationLink(destination: ScenesSettingsView(model: model)) {
                    Text("Scenes")
                }
                NavigationLink(destination: LocalOverlaysSettingsView(model: model)) {
                    Text("Local overlays")
                }
                NavigationLink(destination: ZoomSettingsView(model: model)) {
                    Text("Zoom")
                }
                TapScreenToFocusSettingsView(model: model)
                NavigationLink(destination: BitratePresetsSettingsView(model: model)) {
                    Text("Bitrate presets")
                }
                NavigationLink(destination: MaximumScreenFpsSettingsView(model: model)) {
                    Toggle(isOn: Binding(get: {
                        model.database.maximumScreenFpsEnabled!
                    }, set: { value in
                        model.setMaximumScreenFpsEnabled(value: value)
                    })) {
                        TextItemView(
                            name: "Maximum screen FPS",
                            value: String(model.database.maximumScreenFps!)
                        )
                    }
                }
            } footer: {
                Text("""
                The maximum screen FPS currently gives a lower FPS than \
                configured. The maximum screen FPS cannot exceed the stream FPS.
                """)
            }
            Section {
                NavigationLink(destination: CosmeticsSettingsView(model: model)) {
                    Text("Cosmetics")
                }
            }
            Section {
                NavigationLink(destination: HelpAndSupportSettingsView()) {
                    Text("Help & support")
                }
                NavigationLink(destination: AboutSettingsView()) {
                    Text("About")
                }
                NavigationLink(destination: DebugSettingsView(model: model)) {
                    Text("Debug")
                }
            }
            Section {
                NavigationLink(destination: ImportExportSettingsView(model: model)) {
                    Text("Import and export settings")
                }
            }
            Section {
                ResetSettingsView(model: model)
            }
        }
        .navigationTitle("Settings")
    }
}
