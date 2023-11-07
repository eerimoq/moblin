import SwiftUI

struct SettingsLayoutMenuItem {
    var layout: SettingsLayout
    var image: String
    var text: String
}

private let layoutMenuItems: [SettingsLayoutMenuItem] = [
    SettingsLayoutMenuItem(
        layout: .right,
        image: "rectangle.righthalf.filled",
        text: "Right"
    ),
    SettingsLayoutMenuItem(
        layout: .left,
        image: "rectangle.lefthalf.filled",
        text: "Left"
    ),
    SettingsLayoutMenuItem(layout: .full, image: "rectangle.fill", text: "Full"),
]

struct SettingsView: View {
    @EnvironmentObject var model: Model
    let hideSettings: () -> Void

    private func splitImage() -> Image {
        if model.settingsLayout == .full {
            return Image(systemName: "arrow.down.right.and.arrow.up.left")
        } else {
            return Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
    }

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
                Toggle("Battery percentage", isOn: Binding(get: {
                    model.database.batteryPercentage!
                }, set: { value in
                    model.database.batteryPercentage = value
                    model.store()
                }))
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
                Text("A low maximum screen FPS reduces power usage.")
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
                HStack(spacing: 0) {
                    Picker("", selection: $model.settingsLayout) {
                        ForEach(layoutMenuItems, id: \.layout) { item in
                            Image(systemName: item.image)
                        }
                    }
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
