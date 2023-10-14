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
                NavigationLink(destination: BitratePresetsSettingsView(model: model)) {
                    Text("Bitrate presets")
                }
                NavigationLink(destination: TextEditView(
                    title: "Screen FPS",
                    value: String(model.database.screenVideoFps!),
                    onSubmit: { value in
                        guard let fps = Int(value) else {
                            return
                        }
                        model.setScreenFps(fps: fps)
                    }
                )) {
                    TextItemView(
                        name: "Screen FPS",
                        value: String(model.database.screenVideoFps!)
                    )
                }
                Toggle("Tap screen to focus", isOn: Binding(get: {
                    model.database.tapToFocus!
                }, set: { value in
                    model.database.tapToFocus = value
                    model.store()
                    if !value {
                        model.setAutoFocus()
                    }
                }))
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
