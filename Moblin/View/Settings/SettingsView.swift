import SwiftUI

let settingsHalfWidth = 350.0

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
                NavigationLink {
                    StreamsSettingsView()
                } label: {
                    IconAndTextView(
                        image: "dot.radiowaves.left.and.right",
                        text: String(localized: "Streams")
                    )
                }
                NavigationLink {
                    ScenesSettingsView()
                } label: {
                    IconAndTextView(image: "photo.on.rectangle", text: String(localized: "Scenes"))
                }
                NavigationLink {
                    ChatSettingsView(
                        timestampColor: chat.timestampColor.color(),
                        usernameColor: chat.usernameColor.color(),
                        messageColor: chat.messageColor.color(),
                        backgroundColor: chat.backgroundColor.color(),
                        shadowColor: chat.shadowColor.color(),
                        height: chat.height!,
                        width: chat.width!,
                        bottom: chat.bottom!,
                        fontSize: chat.fontSize
                    )
                } label: {
                    IconAndTextView(image: "message", text: String(localized: "Chat"))
                }
                NavigationLink {
                    DisplaySettingsView()
                } label: {
                    IconAndTextView(
                        image: "rectangle.inset.topright.fill",
                        text: String(localized: "Display")
                    )
                }
                NavigationLink {
                    CameraSettingsView()
                } label: {
                    IconAndTextView(image: "camera", text: String(localized: "Camera"))
                }
                if model.database.showAllSettings! {
                    NavigationLink {
                        AudioSettingsView()
                    } label: {
                        IconAndTextView(image: "waveform", text: String(localized: "Audio"))
                    }
                    NavigationLink {
                        BitratePresetsSettingsView()
                    } label: {
                        IconAndTextView(image: "speedometer", text: String(localized: "Bitrate presets"))
                    }
                }
                NavigationLink {
                    LocationSettingsView()
                } label: {
                    IconAndTextView(image: "location", text: String(localized: "Location"))
                }
                if model.database.showAllSettings! {
                    NavigationLink {
                        WebBrowserSettingsView()
                    } label: {
                        IconAndTextView(image: "globe", text: String(localized: "Web browser"))
                    }
                }
            }
            if model.database.showAllSettings! {
                Section {
                    NavigationLink {
                        RtmpServerSettingsView()
                    } label: {
                        IconAndTextView(image: "server.rack", text: String(localized: "RTMP server"))
                    }
                    NavigationLink {
                        SrtlaServerSettingsView()
                    } label: {
                        IconAndTextView(image: "server.rack", text: String(localized: "SRT(LA) server"))
                    }
                    NavigationLink {
                        MoblinkSettingsView(streamerEnabled: model.database.moblink!.server.enabled)
                    } label: {
                        IconAndTextView(
                            image: "app.connected.to.app.below.fill",
                            text: String(localized: "Moblink")
                        )
                    }
                    NavigationLink {
                        MediaPlayersSettingsView()
                    } label: {
                        IconAndTextView(
                            image: "play.rectangle.on.rectangle",
                            text: String(localized: "Media players")
                        )
                    }
                }
                Section {
                    NavigationLink {
                        GameControllersSettingsView()
                    } label: {
                        IconAndTextView(image: "gamecontroller", text: String(localized: "Game controllers"))
                    }
                    if #available(iOS 17.0, *) {
                        NavigationLink {
                            KeyboardSettingsView()
                        } label: {
                            IconAndTextView(image: "keyboard", text: String(localized: "Keyboard"))
                        }
                    }
                    NavigationLink {
                        RemoteControlSettingsView()
                    } label: {
                        IconAndTextView(
                            image: "appletvremote.gen1",
                            text: String(localized: "Remote control")
                        )
                    }
                }
                Section {
                    NavigationLink {
                        DjiDevicesSettingsView()
                    } label: {
                        IconAndTextView(
                            image: "appletvremote.gen1",
                            text: String(localized: "DJI devices")
                        )
                    }
                    NavigationLink {
                        CatPrintersSettingsView()
                    } label: {
                        IconAndTextView(
                            image: "pawprint",
                            text: String(localized: "Cat printers")
                        )
                    }
                    NavigationLink {
                        TeslaSettingsView()
                    } label: {
                        IconAndTextView(
                            image: "car.side",
                            text: String(localized: "Tesla")
                        )
                    }
                }
            }
            Section {
                NavigationLink {
                    CosmeticsSettingsView()
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .frame(width: iconWidth)
                        Text("Cosmetics")
                    }
                }
            }
            Section {
                NavigationLink {
                    RecordingsSettingsView()
                } label: {
                    IconAndTextView(image: "photo.on.rectangle.angled", text: String(localized: "Recordings"))
                }
                if model.database.showAllSettings! {
                    NavigationLink {
                        StreamingHistorySettingsView()
                    } label: {
                        IconAndTextView(
                            image: "text.book.closed",
                            text: String(localized: "Streaming history")
                        )
                    }
                }
            }
            if model.database.showAllSettings! {
                Section {
                    NavigationLink {
                        WatchSettingsView()
                    } label: {
                        IconAndTextView(image: "applewatch", text: String(localized: "Watch"))
                    }
                }
            }
            Section {
                NavigationLink {
                    HelpAndSupportSettingsView()
                } label: {
                    IconAndTextView(image: "questionmark.circle", text: String(localized: "Help and support"))
                }
                if model.database.showAllSettings! {
                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        IconAndTextView(image: "info.circle", text: String(localized: "About"))
                    }
                    NavigationLink {
                        DebugSettingsView(
                            cameraSwitchRemoveBlackish: model.database.debug.cameraSwitchRemoveBlackish!
                        )
                    } label: {
                        IconAndTextView(image: "ladybug", text: String(localized: "Debug"))
                    }
                }
            }
            if model.database.showAllSettings! {
                Section {
                    NavigationLink {
                        ImportExportSettingsView()
                    } label: {
                        IconAndTextView(
                            image: "gearshape",
                            text: String(localized: "Import and export settings")
                        )
                    }
                    NavigationLink {
                        DeepLinkCreatorSettingsView()
                    } label: {
                        IconAndTextView(
                            image: "link.badge.plus",
                            text: String(localized: "Deep link creator")
                        )
                    }
                }
            }
            Section {
                Toggle("Show all settings", isOn: Binding(get: {
                    model.database.showAllSettings!
                }, set: { value in
                    model.database.showAllSettings = value
                    model.objectWillChange.send()
                }))
            }
            Section {
                ResetSettingsView()
            }
        }
        .navigationTitle("Settings")
    }
}
