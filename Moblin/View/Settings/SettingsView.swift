import SwiftUI

let settingsHalfWidth = 350.0
private let iconWidth = 32.0

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
    var quickDone: (() -> Void)?

    private func layoutImage() -> String {
        return layoutMenuItems.first { item in
            item.layout == model.settingsLayout
        }!.image
    }

    var body: some ToolbarContent {
        if let quickDone {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    quickDone()
                }, label: {
                    Text("Close")
                })
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Menu {
                        Picker("", selection: $model.settingsLayout) {
                            ForEach(layoutMenuItems, id: \.layout) { item in
                                HStack {
                                    Image(systemName: item.image)
                                    Text(item.text)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: layoutImage())
                    }
                    Button(action: {
                        model.showingSettings = false
                    }, label: {
                        Text("Close")
                    })
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: Model

    var chat: SettingsChat {
        model.database.chat
    }

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
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .frame(width: iconWidth)
                        Text("Streams")
                    }
                }
                NavigationLink(destination: ScenesSettingsView()) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .frame(width: iconWidth)
                        Text("Scenes")
                    }
                }
                NavigationLink(destination: LocalOverlaysChatSettingsView(
                    timestampColor: chat.timestampColor.color(),
                    usernameColor: chat.usernameColor.color(),
                    messageColor: chat.messageColor.color(),
                    backgroundColor: chat.backgroundColor.color(),
                    shadowColor: chat.shadowColor.color(),
                    height: chat.height!,
                    width: chat.width!,
                    fontSize: chat.fontSize
                )) {
                    HStack {
                        Image(systemName: "message")
                            .frame(width: iconWidth)
                        Text("Chat")
                    }
                }
                NavigationLink(destination: DisplaySettingsView()) {
                    HStack {
                        Image(systemName: "rectangle.inset.topright.fill")
                            .frame(width: iconWidth)
                        Text("Display")
                    }
                }
                NavigationLink(destination: CameraSettingsView()) {
                    HStack {
                        Image(systemName: "camera")
                            .frame(width: iconWidth)
                        Text("Camera")
                    }
                }
                NavigationLink(destination: BitratePresetsSettingsView()) {
                    HStack {
                        Image(systemName: "speedometer")
                            .frame(width: iconWidth)
                        Text("Bitrate presets")
                    }
                }
                NavigationLink(destination: RtmpServerSettingsView()) {
                    HStack {
                        Image(systemName: "server.rack")
                            .frame(width: iconWidth)
                        Text("RTMP server")
                    }
                }
                NavigationLink(destination: GameControllersSettingsView()) {
                    HStack {
                        Image(systemName: "gamecontroller")
                            .frame(width: iconWidth)
                        Text("Game controllers")
                    }
                }
                NavigationLink(destination: RemoteControlSettingsView()) {
                    HStack {
                        Image(systemName: "appletvremote.gen1")
                            .frame(width: iconWidth)
                        Text("Remote control")
                    }
                }
                NavigationLink(destination: LocationSettingsView()) {
                    HStack {
                        Image(systemName: "location")
                            .frame(width: iconWidth)
                        Text("Location")
                    }
                }
            }
            Section {
                NavigationLink(destination: CosmeticsSettingsView()) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .frame(width: iconWidth)
                        Text("Cosmetics")
                    }
                }
            }
            Section {
                NavigationLink(destination: RecordingsSettingsView()) {
                    HStack {
                        Image(systemName: "film.stack")
                            .frame(width: iconWidth)
                        Text("Recordings")
                    }
                }
                NavigationLink(destination: StreamingHistorySettingsView()) {
                    HStack {
                        Image(systemName: "text.book.closed")
                            .frame(width: iconWidth)
                        Text("Streaming history")
                    }
                }
            }
            Section {
                NavigationLink(destination: WatchSettingsView()) {
                    HStack {
                        Image(systemName: "applewatch")
                            .frame(width: iconWidth)
                        Text("Watch")
                    }
                }
            }
            Section {
                NavigationLink(destination: HelpAndSupportSettingsView()) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .frame(width: iconWidth)
                        Text("Help & support")
                    }
                }
                NavigationLink(destination: AboutSettingsView()) {
                    HStack {
                        Image(systemName: "info.circle")
                            .frame(width: iconWidth)
                        Text("About")
                    }
                }
                NavigationLink(
                    destination: DebugSettingsView(cameraSwitchRemoveBlackish: model.database.debug!
                        .cameraSwitchRemoveBlackish!)
                ) {
                    HStack {
                        Image(systemName: "ladybug")
                            .frame(width: iconWidth)
                        Text("Debug")
                    }
                }
            }
            Section {
                NavigationLink(destination: ImportExportSettingsView()) {
                    HStack {
                        Image(systemName: "gearshape")
                            .frame(width: iconWidth)
                        Text("Import and export settings")
                    }
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
