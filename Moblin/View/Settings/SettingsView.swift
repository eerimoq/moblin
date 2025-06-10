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
                        chat: database.chat,
                        timestampColor: chat.timestampColor.color(),
                        usernameColor: chat.usernameColor.color(),
                        messageColor: chat.messageColor.color(),
                        backgroundColor: chat.backgroundColor.color(),
                        shadowColor: chat.shadowColor.color()
                    )
                } label: {
                    IconAndTextView(image: "message", text: String(localized: "Chat"))
                }
                NavigationLink {
                    DisplaySettingsView(database: database)
                } label: {
                    IconAndTextView(
                        image: "rectangle.inset.topright.fill",
                        text: String(localized: "Display")
                    )
                }
                NavigationLink {
                    CameraSettingsView(database: database)
                } label: {
                    IconAndTextView(image: "camera", text: String(localized: "Camera"))
                }
                if database.showAllSettings {
                    NavigationLink {
                        AudioSettingsView(database: model.database)
                    } label: {
                        IconAndTextView(image: "waveform", text: String(localized: "Audio"))
                    }
                    NavigationLink {
                        BitratePresetsSettingsView(database: model.database)
                    } label: {
                        IconAndTextView(image: "speedometer", text: String(localized: "Bitrate presets"))
                    }
                }
                NavigationLink {
                    LocationSettingsView()
                } label: {
                    IconAndTextView(image: "location", text: String(localized: "Location"))
                }
                if database.showAllSettings {
                    NavigationLink {
                        WebBrowserSettingsView()
                    } label: {
                        IconAndTextView(image: "globe", text: String(localized: "Web browser"))
                    }
                }
            }
            Section {
                if database.showAllSettings {
                    NavigationLink {
                        RtmpServerSettingsView(database: model.database)
                    } label: {
                        IconAndTextView(image: "server.rack", text: String(localized: "RTMP server"))
                    }
                    NavigationLink {
                        SrtlaServerSettingsView(database: model.database)
                    } label: {
                        IconAndTextView(image: "server.rack", text: String(localized: "SRT(LA) server"))
                    }
                }
                NavigationLink {
                    MoblinkSettingsView(streamerEnabled: database.moblink.server.enabled)
                } label: {
                    IconAndTextView(image: "app.connected.to.app.below.fill", text: String(localized: "Moblink"))
                }
                if database.showAllSettings {
                    NavigationLink {
                        MediaPlayersSettingsView(database: model.database)
                    } label: {
                        IconAndTextView(image: "play.rectangle.on.rectangle", text: String(localized: "Media players"))
                    }
                }
            }
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        SelfieStickSettingsView(selfieStick: database.selfieStick)
                    } label: {
                        IconAndTextView(image: "line.diagonal", text: String(localized: "Selfie stick"))
                    }
                    NavigationLink {
                        GameControllersSettingsView(database: model.database)
                    } label: {
                        IconAndTextView(image: "gamecontroller", text: String(localized: "Game controllers"))
                    }
                    if #available(iOS 17.0, *) {
                        NavigationLink {
                            KeyboardSettingsView(keyboard: model.database.keyboard)
                        } label: {
                            IconAndTextView(image: "keyboard", text: String(localized: "Keyboard"))
                        }
                    }
                    NavigationLink {
                        RemoteControlSettingsView(database: model.database)
                    } label: {
                        IconAndTextView(image: "appletvremote.gen1", text: String(localized: "Remote control"))
                    }
                }
                Section {
                    NavigationLink {
                        DjiDevicesSettingsView(djiDevices: model.database.djiDevices)
                    } label: {
                        IconAndTextView(image: "appletvremote.gen1", text: String(localized: "DJI devices"))
                    }
                    NavigationLink {
                        GoProSettingsView()
                    } label: {
                        IconAndTextView(image: "appletvremote.gen1", text: String(localized: "GoPro"))
                    }
                    NavigationLink {
                        CatPrintersSettingsView(catPrinters: model.database.catPrinters)
                    } label: {
                        IconAndTextView(image: "pawprint", text: String(localized: "Cat printers"))
                    }
                    NavigationLink {
                        TeslaSettingsView()
                    } label: {
                        IconAndTextView(image: "car.side", text: String(localized: "Tesla"))
                    }
                    NavigationLink {
                        CyclingPowerDevicesSettingsView()
                    } label: {
                        IconAndTextView(image: "bicycle", text: String(localized: "Cycling power devices"))
                    }
                    NavigationLink {
                        HeartRateDevicesSettingsView()
                    } label: {
                        IconAndTextView(image: "heart", text: String(localized: "Heart rate devices"))
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
                if database.showAllSettings {
                    NavigationLink {
                        StreamingHistorySettingsView()
                    } label: {
                        IconAndTextView(image: "text.book.closed", text: String(localized: "Streaming history"))
                    }
                }
            }
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        WatchSettingsView()
                    } label: {
                        IconAndTextView(image: "applewatch", text: String(localized: "Apple Watch"))
                    }
                }
            }
            Section {
                NavigationLink {
                    HelpAndSupportSettingsView()
                } label: {
                    IconAndTextView(image: "questionmark.circle", text: String(localized: "Help and support"))
                }
                if database.showAllSettings {
                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        IconAndTextView(image: "info.circle", text: String(localized: "About"))
                    }
                    NavigationLink {
                        DebugSettingsView(debug: database.debug)
                    } label: {
                        IconAndTextView(image: "ladybug", text: String(localized: "Debug"))
                    }
                }
            }
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        ImportExportSettingsView()
                    } label: {
                        IconAndTextView(image: "gearshape", text: String(localized: "Import and export settings"))
                    }
                    NavigationLink {
                        DeepLinkCreatorSettingsView(deepLinkCreator: model.database.deepLinkCreator)
                    } label: {
                        IconAndTextView(image: "link.badge.plus", text: String(localized: "Deep link creator"))
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
