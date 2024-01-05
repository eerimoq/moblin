import SwiftUI

let settingsHalfWidth = 350.0

enum SettingsLayout {
    case full
    case left
    case right
}

struct SettingsLayoutMenuItem {
    var layout: SettingsLayout
    var image: String
    var text: String
}

private let layoutMenuItems = [
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

struct SettingsToolbar: ToolbarContent {
    @EnvironmentObject var model: Model

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Picker("", selection: $model.settingsLayout) {
                    ForEach(layoutMenuItems, id: \.layout) { item in
                        Image(systemName: item.image)
                    }
                }
                .padding([.trailing], -10)
                Button(action: {
                    model.showingSettings = false
                }, label: {
                    Text("Close")
                })
            }
        }
    }
}

struct QuickSettingsToolbar: ToolbarContent {
    let done: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                done()
            }, label: {
                Text("Close")
            })
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            if model.isLive {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(
                            "Settings that would stop the stream are disabled when live."
                        )
                    }
                }
            }
            Section {
                NavigationLink(destination: StreamsSettingsView()) {
                    Text("Streams")
                }
                NavigationLink(destination: ScenesSettingsView()) {
                    Text("Scenes")
                }
                NavigationLink(destination: DisplaySettingsView()) {
                    Text("Display")
                }
                NavigationLink(destination: CameraSettingsView()) {
                    Text("Camera")
                }
                NavigationLink(destination: BitratePresetsSettingsView()) {
                    Text("Bitrate presets")
                }
                NavigationLink(destination: RtmpServerSettingsView()) {
                    Text("RTMP server")
                }
                NavigationLink(destination: GameControllersSettingsView()) {
                    Text("Game controllers")
                }
            }
            Section {
                NavigationLink(destination: CosmeticsSettingsView()) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Cosmetics")
                    }
                }
            }
            Section {
                NavigationLink(destination: RecordingsSettingsView()) {
                    Text("Recordings")
                }
                NavigationLink(destination: StreamingHistorySettingsView()) {
                    Text("Streaming history")
                }
            }
            Section {
                NavigationLink(destination: HelpAndSupportSettingsView()) {
                    Text("Help & support")
                }
                NavigationLink(destination: AboutSettingsView()) {
                    Text("About")
                }
                NavigationLink(
                    destination: DebugSettingsView(srtOverheadBandwidth: Float(model
                            .database.debug!.srtOverheadBandwidth!))
                ) {
                    Text("Debug")
                }
            }
            Section {
                NavigationLink(destination: ImportExportSettingsView()) {
                    Text("Import and export settings")
                }
            }
            Section {
                ResetSettingsView()
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            SettingsToolbar()
        }
    }
}
