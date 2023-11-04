import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: Model
    let toggleWideSettings: () -> Void
    let hideSettings: () -> Void
    let splitImage: () -> Image

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: StreamsSettingsView()) {
                    Text("Streams")
                }
                NavigationLink(destination: ScenesSettingsView()) {
                    Text("Scenes")
                }
                NavigationLink(
                    destination: LocalOverlaysSettingsView()
                ) {
                    Text("Local overlays")
                }
                NavigationLink(destination: ZoomSettingsView()) {
                    Text("Zoom")
                }
                TapScreenToFocusSettingsView()
                NavigationLink(
                    destination: BitratePresetsSettingsView()
                ) {
                    Text("Bitrate presets")
                }
                VideoStabilizationSettingsView()
                NavigationLink(
                    destination: MaximumScreenFpsSettingsView()
                ) {
                    Toggle(isOn: Binding(get: {
                        model.database.maximumScreenFpsEnabled
                    }, set: { value in
                        model.setMaximumScreenFpsEnabled(value: value)
                    })) {
                        TextItemView(
                            name: "Maximum screen FPS",
                            value: String(model.database.maximumScreenFps)
                        )
                    }
                }
            } footer: {
                Text("""
                The maximum screen FPS currently gives a lower FPS than \
                configured. The maximum screen FPS cannot exceed the stream FPS \
                (\(model.stream.fps) for current stream).
                """)
            }
            Section {
                NavigationLink(destination: CosmeticsSettingsView(
                )) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Cosmetics")
                    }
                }
            }
            Section {
                NavigationLink(
                    destination: HelpAndSupportSettingsView()
                ) {
                    Text("Help & support")
                }
                NavigationLink(destination: AboutSettingsView()) {
                    Text("About")
                }
                NavigationLink(destination: DebugSettingsView()) {
                    Text("Debug")
                }
            }
            Section {
                NavigationLink(
                    destination: ImportExportSettingsView()
                ) {
                    Text("Import and export settings")
                }
            }
            Section {
                ResetSettingsView()
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        toggleWideSettings()
                    }, label: {
                        splitImage()
                    })
                    Button(action: {
                        hideSettings()
                    }, label: {
                        Text("Close")
                    })
                }
            }
        }
    }
}
