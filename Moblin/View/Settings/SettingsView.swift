import SwiftUI

let settingsHalfWidth = 350.0

struct SettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Form {
            if model.isLive {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Settings that would stop the stream are disabled when live.")
                    }
                }
            }
            Section {
                NavigationLink {
                    StreamsSettingsView(createStreamWizard: model.createStreamWizard, database: database)
                } label: {
                    Label("Streams", systemImage: "dot.radiowaves.left.and.right")
                }
                NavigationLink {
                    ScenesSettingsView()
                } label: {
                    Label("Scenes", systemImage: "photo.on.rectangle")
                }
                NavigationLink {
                    ChatSettingsView(chat: database.chat, stream: model.stream)
                } label: {
                    Label("Chat", systemImage: "message")
                }
                NavigationLink {
                    DisplaySettingsView(database: database)
                } label: {
                    Label("Display", systemImage: "rectangle.inset.topright.fill")
                }
                NavigationLink {
                    CameraSettingsView(database: database, stream: model.stream, color: database.color)
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                if database.showAllSettings {
                    NavigationLink {
                        AudioSettingsView(database: database,
                                          stream: model.stream,
                                          mic: model.mic,
                                          debug: database.debug)
                    } label: {
                        Label("Audio", systemImage: "waveform")
                    }
                }
                NavigationLink {
                    LocationSettingsView(database: database, location: database.location, stream: $model.stream)
                } label: {
                    Label("Location", systemImage: "location")
                }
            }
            Section {
                if database.showAllSettings {
                    NavigationLink {
                        IngestsSettingsView(database: database)
                    } label: {
                        Label("Ingests", systemImage: "server.rack")
                    }
                }
                NavigationLink {
                    MoblinkSettingsView(status: model.statusOther, streamer: database.moblink.streamer)
                } label: {
                    Label("Moblink", systemImage: "app.connected.to.app.below.fill")
                }
                if database.showAllSettings {
                    NavigationLink {
                        MediaPlayersSettingsView(mediaPlayers: database.mediaPlayers)
                    } label: {
                        Label("Media players", systemImage: "play.rectangle.on.rectangle")
                    }
                }
            }
            if database.showAllSettings {
                Section {
                    NavigationLink {
                        SelfieStickSettingsView(database: database, selfieStick: database.selfieStick)
                    } label: {
                        Label("Selfie stick", systemImage: "line.diagonal")
                    }
                    NavigationLink {
                        GameControllersSettingsView(database: database)
                    } label: {
                        Label("Game controllers", systemImage: "gamecontroller")
                    }
                    if #available(iOS 17.0, *) {
                        NavigationLink {
                            KeyboardSettingsView(keyboard: database.keyboard)
                        } label: {
                            Label("Keyboard", systemImage: "keyboard")
                        }
                    }
                    NavigationLink {
                        RemoteControlSettingsView(database: database,
                                                  status: model.statusOther,
                                                  assistant: database.remoteControl.assistant,
                                                  stream: $model.stream)
                    } label: {
                        Label("Remote control", systemImage: "appletvremote.gen1")
                    }
                }
                Section {
                    NavigationLink {
                        DjiDevicesSettingsView(djiDevices: database.djiDevices)
                    } label: {
                        Label("DJI devices", systemImage: "appletvremote.gen1")
                    }
                    NavigationLink {
                        GoProSettingsView()
                    } label: {
                        Label("GoPro", systemImage: "appletvremote.gen1")
                    }
                    NavigationLink {
                        CatPrintersSettingsView(catPrinters: database.catPrinters)
                    } label: {
                        Label("Cat printers", systemImage: "pawprint")
                    }
                    NavigationLink {
                        TeslaSettingsView(tesla: model.tesla)
                    } label: {
                        Label("Tesla", systemImage: "car.side")
                    }
                    NavigationLink {
                        CyclingPowerDevicesSettingsView(cyclingPowerDevices: database.cyclingPowerDevices)
                    } label: {
                        Label("Cycling power devices", systemImage: "bicycle")
                    }
                    NavigationLink {
                        HeartRateDevicesSettingsView(heartRateDevices: database.heartRateDevices)
                    } label: {
                        Label("Heart rate devices", systemImage: "heart")
                    }
                    NavigationLink {
                        BlackSharkCoolerDevicesSettingsView(blackSharkCoolerDevices: database.blackSharkCoolerDevices)
                    } label: {
                        Label("Black Shark coolers", systemImage: "fan")
                    }
                }
            }
            Section {
                NavigationLink {
                    CosmeticsSettingsView(cosmetics: model.cosmetics)
                } label: {
                    Label {
                        Text("Cosmetics")
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            Section {
                NavigationLink {
                    RecordingsSettingsView(model: model)
                } label: {
                    Label("Recordings", systemImage: "photo.on.rectangle.angled")
                }
                if database.showAllSettings {
                    NavigationLink {
                        StreamingHistorySettingsView(model: model)
                    } label: {
                        Label("Streaming history", systemImage: "text.book.closed")
                    }
                }
            }
            if database.showAllSettings, isPhone() {
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
                        DeepLinkCreatorSettingsView(deepLinkCreator: database.deepLinkCreator)
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
