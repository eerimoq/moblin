import SwiftUI

let settingsHalfWidth = 350.0

struct SettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var chat: SettingsChat {
        database.chat
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
                    StreamsSettingsView(database: database)
                } label: {
                    Label("Streams", systemImage: "dot.radiowaves.left.and.right")
                }
                NavigationLink {
                    ScenesSettingsView()
                } label: {
                    Label("Scenes", systemImage: "photo.on.rectangle")
                }
                NavigationLink {
                    ChatSettingsView(
                        chat: database.chat,
                        timestampColor: chat.timestampColor.color(),
                        usernameColor: chat.usernameColor.color(),
                        messageColor: chat.messageColor.color(),
                        backgroundColor: chat.backgroundColor.color(),
                        shadowColor: chat.shadowColor.color()
                    )
                } label: {
                    Label("Chat", systemImage: "message")
                }
                NavigationLink {
                    DisplaySettingsView(database: database)
                } label: {
                    Label("Display", systemImage: "rectangle.inset.topright.fill")
                }
                NavigationLink {
                    CameraSettingsView(database: database)
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                if database.showAllSettings {
                    NavigationLink {
                        AudioSettingsView(database: model.database)
                    } label: {
                        Label("Audio", systemImage: "waveform")
                    }
                    NavigationLink {
                        BitratePresetsSettingsView(database: model.database)
                    } label: {
                        Label("Bitrate presets", systemImage: "speedometer")
                    }
                }
                NavigationLink {
                    LocationSettingsView()
                } label: {
                    Label("Location", systemImage: "location")
                }
                if database.showAllSettings {
                    NavigationLink {
                        WebBrowserSettingsView()
                    } label: {
                        Label("Web browser", systemImage: "globe")
                    }
                }
            }
            Section {
                if database.showAllSettings {
                    NavigationLink {
                        RtmpServerSettingsView(database: model.database)
                    } label: {
                        Label("RTMP server", systemImage: "server.rack")
                    }
                    NavigationLink {
                        SrtlaServerSettingsView(database: model.database)
                    } label: {
                        Label("SRT(LA) server", systemImage: "server.rack")
                    }
                }
                NavigationLink {
                    MoblinkSettingsView(streamerEnabled: database.moblink.server.enabled)
                } label: {
                    Label("Moblink", systemImage: "app.connected.to.app.below.fill")
                }
                if database.showAllSettings {
                    NavigationLink {
                        MediaPlayersSettingsView(mediaPlayers: model.database.mediaPlayers)
                    } label: {
                        Label("Media players", systemImage: "play.rectangle.on.rectangle")
                    }
                }
            }
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        SelfieStickSettingsView(selfieStick: database.selfieStick)
                    } label: {
                        Label("Selfie stick", systemImage: "line.diagonal")
                    }
                    NavigationLink {
                        GameControllersSettingsView(database: model.database)
                    } label: {
                        Label("Game controllers", systemImage: "gamecontroller")
                    }
                    if #available(iOS 17.0, *) {
                        NavigationLink {
                            KeyboardSettingsView(keyboard: model.database.keyboard)
                        } label: {
                            Label("Keyboard", systemImage: "keyboard")
                        }
                    }
                    NavigationLink {
                        RemoteControlSettingsView(database: model.database)
                    } label: {
                        Label("Remote control", systemImage: "appletvremote.gen1")
                    }
                }
                Section {
                    NavigationLink {
                        DjiDevicesSettingsView(djiDevices: model.database.djiDevices)
                    } label: {
                        Label("DJI devices", systemImage: "appletvremote.gen1")
                    }
                    NavigationLink {
                        GoProSettingsView()
                    } label: {
                        Label("GoPro", systemImage: "appletvremote.gen1")
                    }
                    NavigationLink {
                        CatPrintersSettingsView(catPrinters: model.database.catPrinters)
                    } label: {
                        Label("Cat printers", systemImage: "pawprint")
                    }
                    NavigationLink {
                        TeslaSettingsView()
                    } label: {
                        Label("Tesla", systemImage: "car.side")
                    }
                    NavigationLink {
                        CyclingPowerDevicesSettingsView()
                    } label: {
                        Label("Cycling power devices", systemImage: "bicycle")
                    }
                    NavigationLink {
                        HeartRateDevicesSettingsView()
                    } label: {
                        Label("Heart rate devices", systemImage: "heart")
                    }
                    NavigationLink {
                        PhoneCoolerDevicesSettingsView()
                    } label: {
                        IconAndTextView(image: "fan.fill", text: String(localized: "Phone Coolers"))
                    }
                }
            }
            Section {
                NavigationLink {
                    CosmeticsSettingsView()
                } label: {
                    Label {
                        Text("Cosmetics")
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            Section {
                NavigationLink {
                    RecordingsSettingsView()
                } label: {
                    Label("Recordings", systemImage: "photo.on.rectangle.angled")
                }
                if database.showAllSettings {
                    NavigationLink {
                        StreamingHistorySettingsView()
                    } label: {
                        Label("Streaming history", systemImage: "text.book.closed")
                    }
                }
            }
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        WatchSettingsView(watch: database.watch)
                    } label: {
                        Label("Apple Watch", systemImage: "applewatch")
                    }
                }
            }
            Section {
                NavigationLink {
                    HelpAndSupportSettingsView()
                } label: {
                    Label("Help and support", systemImage: "questionmark.circle")
                }
                if database.showAllSettings {
                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    NavigationLink {
                        DebugSettingsView(debug: database.debug)
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                }
            }
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        ImportExportSettingsView()
                    } label: {
                        Label("Import and export settings", systemImage: "gearshape")
                    }
                    NavigationLink {
                        DeepLinkCreatorSettingsView(deepLinkCreator: model.database.deepLinkCreator)
                    } label: {
                        Label("Deep link creator", systemImage: "link.badge.plus")
                    }
                }
            }
            Section {
                Toggle("Show all settings", isOn: $database.showAllSettings)
            }
            Section {
                ResetSettingsView()
            }
        }
        .navigationTitle("Settings")
    }
}
