import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

    var body: some View {
        ZStack {
            Form {
                Section {
                    NavigationLink(destination: StreamsSettingsView(
                        model: model,
                        toolbar: toolbar
                    )) {
                        Text("Streams")
                    }
                    NavigationLink(destination: ScenesSettingsView(
                        model: model,
                        toolbar: toolbar
                    )) {
                        Text("Scenes")
                    }
                    NavigationLink(destination: LocalOverlaysSettingsView(
                        model: model,
                        toolbar: toolbar
                    )) {
                        Text("Local overlays")
                    }
                    NavigationLink(destination: ZoomSettingsView(
                        model: model,
                        toolbar: toolbar
                    )) {
                        Text("Zoom")
                    }
                    TapScreenToFocusSettingsView(model: model)
                    NavigationLink(destination: BitratePresetsSettingsView(
                        model: model, toolbar: toolbar
                    )) {
                        Text("Bitrate presets")
                    }
                    VideoStabilizationSettingsView(model: model, toolbar: toolbar)
                    NavigationLink(
                        destination: MaximumScreenFpsSettingsView(
                            model: model,
                            toolbar: toolbar
                        )
                    ) {
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
                    configured. The maximum screen FPS cannot exceed the stream FPS \
                    (\(model.stream.fps) for current stream).
                    """)
                }
                Section {
                    NavigationLink(destination: CosmeticsSettingsView(
                        model: model,
                        toolbar: toolbar
                    )) {
                        Text("Cosmetics")
                    }
                }
                Section {
                    NavigationLink(
                        destination: HelpAndSupportSettingsView(toolbar: toolbar)
                    ) {
                        Text("Help & support")
                    }
                    NavigationLink(destination: AboutSettingsView(toolbar: toolbar)) {
                        Text("About")
                    }
                    NavigationLink(destination: DebugSettingsView(
                        model: model,
                        toolbar: toolbar
                    )) {
                        Text("Debug")
                    }
                }
                Section {
                    NavigationLink(destination: ImportExportSettingsView(
                        model: model,
                        toolbar: toolbar
                    )) {
                        Text("Import and export settings")
                    }
                }
                Section {
                    ResetSettingsView(model: model)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                toolbar
            }
        }
    }
}
