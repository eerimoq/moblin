import SwiftUI

let settingsHalfWidth = 350.0

enum SettingsLayout {
    case full
    case left
    case right
}

private struct SettingsLayoutMenuItem {
    var layout: SettingsLayout
    var image: String
    var text: String
}

private let layoutMenuItems = [
    SettingsLayoutMenuItem(
        layout: .right,
        image: "rectangle.righthalf.filled",
        text: String(localized: "Right")
    ),
    SettingsLayoutMenuItem(
        layout: .left,
        image: "rectangle.lefthalf.filled",
        text: String(localized: "Left")
    ),
    SettingsLayoutMenuItem(layout: .full, image: "rectangle.fill", text: String(localized: "Full")),
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
                    IconAndTextView(
                        image: "dot.radiowaves.left.and.right",
                        text: String(localized: "Streams")
                    )
                }
                NavigationLink(destination: ScenesSettingsView()) {
                    IconAndTextView(image: "photo.on.rectangle", text: String(localized: "Scenes"))
                }
                NavigationLink(destination: ChatSettingsView(
                    timestampColor: chat.timestampColor.color(),
                    usernameColor: chat.usernameColor.color(),
                    messageColor: chat.messageColor.color(),
                    backgroundColor: chat.backgroundColor.color(),
                    shadowColor: chat.shadowColor.color(),
                    height: chat.height!,
                    width: chat.width!,
                    fontSize: chat.fontSize
                )) {
                    IconAndTextView(image: "message", text: String(localized: "Chat"))
                }
                NavigationLink(destination: DisplaySettingsView()) {
                    IconAndTextView(
                        image: "rectangle.inset.topright.fill",
                        text: String(localized: "Display")
                    )
                }
                NavigationLink(destination: CameraSettingsView()) {
                    IconAndTextView(image: "camera", text: String(localized: "Camera"))
                }
                NavigationLink(destination: AudioSettingsView()) {
                    IconAndTextView(image: "waveform", text: String(localized: "Audio"))
                }
                NavigationLink(destination: BitratePresetsSettingsView()) {
                    IconAndTextView(image: "speedometer", text: String(localized: "Bitrate presets"))
                }
                NavigationLink(destination: RtmpServerSettingsView()) {
                    IconAndTextView(image: "server.rack", text: String(localized: "RTMP server"))
                }
                NavigationLink(destination: SrtlaServerSettingsView()) {
                    IconAndTextView(image: "server.rack", text: String(localized: "SRT(LA) server"))
                }
                NavigationLink(destination: GameControllersSettingsView()) {
                    IconAndTextView(image: "gamecontroller", text: String(localized: "Game controllers"))
                }
                NavigationLink(destination: RemoteControlSettingsView()) {
                    IconAndTextView(image: "appletvremote.gen1", text: String(localized: "Remote control"))
                }
                NavigationLink(destination: LocationSettingsView()) {
                    IconAndTextView(image: "location", text: String(localized: "Location"))
                }
                NavigationLink(destination: WebBrowserSettingsView()) {
                    IconAndTextView(image: "globe", text: String(localized: "Web browser"))
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
                    IconAndTextView(image: "photo.on.rectangle.angled", text: String(localized: "Recordings"))
                }
                NavigationLink(destination: StreamingHistorySettingsView()) {
                    IconAndTextView(image: "text.book.closed", text: String(localized: "Streaming history"))
                }
            }
            Section {
                NavigationLink(destination: WatchSettingsView()) {
                    IconAndTextView(image: "applewatch", text: String(localized: "Watch"))
                }
            }
            Section {
                NavigationLink(destination: HelpAndSupportSettingsView()) {
                    IconAndTextView(image: "questionmark.circle", text: String(localized: "Help and support"))
                }
                NavigationLink(destination: AboutSettingsView()) {
                    IconAndTextView(image: "info.circle", text: String(localized: "About"))
                }
                NavigationLink(
                    destination: DebugSettingsView(cameraSwitchRemoveBlackish: model.database.debug!
                        .cameraSwitchRemoveBlackish!)
                ) {
                    IconAndTextView(image: "ladybug", text: String(localized: "Debug"))
                }
            }
            Section {
                NavigationLink(destination: ImportExportSettingsView()) {
                    IconAndTextView(image: "gearshape", text: String(localized: "Import and export settings"))
                }
                NavigationLink(destination: DeepLinkCreatorSettingsView()) {
                    IconAndTextView(image: "link.badge.plus", text: String(localized: "Deep link creator"))
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
