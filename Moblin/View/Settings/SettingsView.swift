import SwiftUI

let settingsHalfWidth = 350.0

private enum SettingsSearchDestination {
    case streams
    case scenes
    case chat
    case display
    case camera
    case audio
    case location
    case store
    case ingests
    case moblink
    case mediaPlayers
    case selfieStick
    case gameControllers
    case keyboard
    case remoteControl
    case djiDevices
    case goPro
    case catPrinters
    case tesla
    case workoutDevices
    case blackSharkCoolers
    case recordings
    case streamingHistory
    case watch
    case helpAndSupport
    case about
    case debug
    case importExport
    case deepLinkCreator
}

private struct SettingsSearchItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let destination: SettingsSearchDestination
}

struct SettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @State private var searchText = ""

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var allSettingsItems: [SettingsSearchItem] {
        var items: [SettingsSearchItem] = []
        items.append(.init(title: String(localized: "Streams"),
                           icon: "dot.radiowaves.left.and.right", destination: .streams))
        items.append(.init(title: String(localized: "Scenes"),
                           icon: "photo.on.rectangle", destination: .scenes))
        items.append(.init(title: String(localized: "Chat"),
                           icon: "message", destination: .chat))
        items.append(.init(title: String(localized: "Display"),
                           icon: "rectangle.inset.topright.fill", destination: .display))
        items.append(.init(title: String(localized: "Camera"),
                           icon: "camera", destination: .camera))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Audio"),
                               icon: "waveform", destination: .audio))
        }
        items.append(.init(title: String(localized: "Location"),
                           icon: "location", destination: .location))
        items.append(.init(title: String(localized: "Store (support us) ❤️"),
                           icon: "cart", destination: .store))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Ingests"),
                               icon: "server.rack", destination: .ingests))
        }
        items.append(.init(title: String(localized: "Moblink"),
                           icon: "app.connected.to.app.below.fill", destination: .moblink))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Media players"),
                               icon: "play.rectangle.on.rectangle", destination: .mediaPlayers))
            items.append(.init(title: String(localized: "Selfie stick"),
                               icon: "line.diagonal", destination: .selfieStick))
            items.append(.init(title: String(localized: "Game controllers"),
                               icon: "gamecontroller", destination: .gameControllers))
            if #available(iOS 17.0, *) {
                items.append(.init(title: String(localized: "Keyboard"),
                                   icon: "keyboard", destination: .keyboard))
            }
            items.append(.init(title: String(localized: "Remote control"),
                               icon: "appletvremote.gen1", destination: .remoteControl))
            items.append(.init(title: String(localized: "DJI devices"),
                               icon: "appletvremote.gen1", destination: .djiDevices))
            items.append(.init(title: String(localized: "GoPro"),
                               icon: "appletvremote.gen1", destination: .goPro))
            items.append(.init(title: String(localized: "Cat printers"),
                               icon: "pawprint", destination: .catPrinters))
            items.append(.init(title: String(localized: "Tesla"),
                               icon: "car.side", destination: .tesla))
            items.append(.init(title: String(localized: "Workout devices"),
                               icon: "figure.walk.motion", destination: .workoutDevices))
            items.append(.init(title: String(localized: "Black Shark coolers"),
                               icon: "fan", destination: .blackSharkCoolers))
        }
        items.append(.init(title: String(localized: "Recordings"),
                           icon: "photo.on.rectangle.angled", destination: .recordings))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Streaming history"),
                               icon: "text.book.closed", destination: .streamingHistory))
        }
        if database.showAllSettings, isPhone() {
            items.append(.init(title: String(localized: "Apple Watch"),
                               icon: "applewatch", destination: .watch))
        }
        items.append(.init(title: String(localized: "Help and support"),
                           icon: "questionmark.circle", destination: .helpAndSupport))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "About"),
                               icon: "info.circle", destination: .about))
            items.append(.init(title: String(localized: "Debug"),
                               icon: "ladybug", destination: .debug))
            items.append(.init(title: String(localized: "Import and export settings"),
                               icon: "gearshape", destination: .importExport))
            items.append(.init(title: String(localized: "Deep link creator"),
                               icon: "link.badge.plus", destination: .deepLinkCreator))
        }
        return items
    }

    private var filteredSettingsItems: [SettingsSearchItem] {
        allSettingsItems.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    @ViewBuilder
    private func destinationView(for destination: SettingsSearchDestination) -> some View {
        switch destination {
        case .streams:
            StreamsSettingsView(createStreamWizard: model.createStreamWizard, database: database)
        case .scenes:
            ScenesSettingsView(database: database)
        case .chat:
            ChatSettingsView(chat: database.chat, stream: model.stream)
        case .display:
            DisplaySettingsView(database: database)
        case .camera:
            CameraSettingsView(database: database, stream: model.stream, color: database.color)
        case .audio:
            AudioSettingsView(database: database,
                              stream: model.stream,
                              mic: model.mic,
                              debug: database.debug,
                              audio: database.audio)
        case .location:
            LocationSettingsView(database: database,
                                 location: database.location,
                                 stream: $model.stream)
        case .store:
            StoreSettingsView(store: model.store)
        case .ingests:
            IngestsSettingsView(model: model, database: database)
        case .moblink:
            MoblinkSettingsView(status: model.statusOther, streamer: database.moblink.streamer)
        case .mediaPlayers:
            MediaPlayersSettingsView(mediaPlayers: database.mediaPlayers)
        case .selfieStick:
            SelfieStickSettingsView(model: model, selfieStick: database.selfieStick)
        case .gameControllers:
            GameControllersSettingsView(model: model, database: database)
        case .keyboard:
            KeyboardSettingsView(model: model, keyboard: database.keyboard)
        case .remoteControl:
            RemoteControlSettingsView(database: database, stream: $model.stream)
        case .djiDevices:
            DjiDevicesSettingsView(djiDevices: database.djiDevices)
        case .goPro:
            GoProSettingsView()
        case .catPrinters:
            CatPrintersSettingsView(catPrinters: database.catPrinters)
        case .tesla:
            TeslaSettingsView(tesla: model.tesla)
        case .workoutDevices:
            WorkoutDevicesSettingsView(workoutDevices: database.workoutDevices)
        case .blackSharkCoolers:
            BlackSharkCoolerDevicesSettingsView(blackSharkCoolerDevices: database
                .blackSharkCoolerDevices)
        case .recordings:
            RecordingsSettingsView(model: model)
        case .streamingHistory:
            StreamingHistorySettingsView(model: model)
        case .watch:
            WatchSettingsView(watch: database.watch)
        case .helpAndSupport:
            HelpAndSupportSettingsView()
        case .about:
            AboutSettingsView()
        case .debug:
            DebugSettingsView(debug: database.debug)
        case .importExport:
            ImportExportSettingsView()
        case .deepLinkCreator:
            DeepLinkCreatorSettingsView(deepLinkCreator: database.deepLinkCreator)
        }
    }

    var body: some View {
        Form {
            if isSearching {
                ForEach(filteredSettingsItems) { item in
                    NavigationLink {
                        destinationView(for: item.destination)
                    } label: {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            } else {
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
                        StreamsSettingsView(createStreamWizard: model.createStreamWizard,
                                            database: database)
                    } label: {
                        Label("Streams", systemImage: "dot.radiowaves.left.and.right")
                    }
                    NavigationLink {
                        ScenesSettingsView(database: database)
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
                        CameraSettingsView(database: database, stream: model.stream,
                                           color: database.color)
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    if database.showAllSettings {
                        NavigationLink {
                            AudioSettingsView(database: database,
                                              stream: model.stream,
                                              mic: model.mic,
                                              debug: database.debug,
                                              audio: database.audio)
                        } label: {
                            Label("Audio", systemImage: "waveform")
                        }
                    }
                    NavigationLink {
                        LocationSettingsView(
                            database: database,
                            location: database.location,
                            stream: $model.stream
                        )
                    } label: {
                        Label("Location", systemImage: "location")
                    }
                }
                Section {
                    NavigationLink {
                        StoreSettingsView(store: model.store)
                    } label: {
                        Label {
                            Text("Store (support us) ❤️")
                        } icon: {
                            Image(systemName: "cart")
                        }
                    }
                }
                Section {
                    if database.showAllSettings {
                        NavigationLink {
                            IngestsSettingsView(model: model, database: database)
                        } label: {
                            Label("Ingests", systemImage: "server.rack")
                        }
                    }
                    NavigationLink {
                        MoblinkSettingsView(status: model.statusOther,
                                            streamer: database.moblink.streamer)
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
                            SelfieStickSettingsView(model: model, selfieStick: database.selfieStick)
                        } label: {
                            Label("Selfie stick", systemImage: "line.diagonal")
                        }
                        NavigationLink {
                            GameControllersSettingsView(model: model, database: database)
                        } label: {
                            Label("Game controllers", systemImage: "gamecontroller")
                        }
                        if #available(iOS 17.0, *) {
                            NavigationLink {
                                KeyboardSettingsView(model: model, keyboard: database.keyboard)
                            } label: {
                                Label("Keyboard", systemImage: "keyboard")
                            }
                        }
                        NavigationLink {
                            RemoteControlSettingsView(database: database, stream: $model.stream)
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
                            WorkoutDevicesSettingsView(workoutDevices: database.workoutDevices)
                        } label: {
                            Label("Workout devices", systemImage: "figure.walk.motion")
                        }
                        NavigationLink {
                            BlackSharkCoolerDevicesSettingsView(blackSharkCoolerDevices: database
                                .blackSharkCoolerDevices)
                        } label: {
                            Label("Black Shark coolers", systemImage: "fan")
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
        }
        .searchable(text: $searchText, prompt: "Search settings")
        .navigationTitle("Settings")
    }
}
