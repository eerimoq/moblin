import SwiftUI

let settingsHalfWidth = 350.0

private enum SettingsSearchDestination {
    // Top level
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
    // Chat sub-items
    case chatBot
    case chatTextToSpeech
    // Display sub-items
    case displayQuickButtons
    case displayStreamButton
    case displayLocalOverlays
    case displayNetworkInterfaceNames
    // Camera sub-items
    case cameraVideo
    case cameraZoom
    case cameraLuts
    // Audio sub-items
    case audioMic
    // Location sub-items
    case locationRealtimeIrl
    // Debug sub-items
    case debugVideo
    // About sub-items
    case aboutAttributions
    // Watch sub-items
    case watchChat
    case watchDisplay
}

private struct SettingsSearchItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let destination: SettingsSearchDestination
    var path: String?
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
        // Streams
        items.append(.init(title: String(localized: "Streams"),
                           icon: "dot.radiowaves.left.and.right", destination: .streams))
        // Scenes
        items.append(.init(title: String(localized: "Scenes"),
                           icon: "photo.on.rectangle", destination: .scenes))
        // Chat
        items.append(.init(title: String(localized: "Chat"),
                           icon: "message", destination: .chat))
        items.append(.init(title: String(localized: "Bot"),
                           icon: "message", destination: .chatBot,
                           path: String(localized: "Chat")))
        items.append(.init(title: String(localized: "Text to speech"),
                           icon: "message", destination: .chatTextToSpeech,
                           path: String(localized: "Chat")))
        // Display
        items.append(.init(title: String(localized: "Display"),
                           icon: "rectangle.inset.topright.fill", destination: .display))
        items.append(.init(title: String(localized: "Quick buttons"),
                           icon: "rectangle.inset.topright.fill",
                           destination: .displayQuickButtons,
                           path: String(localized: "Display")))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Stream button"),
                               icon: "rectangle.inset.topright.fill",
                               destination: .displayStreamButton,
                               path: String(localized: "Display")))
            items.append(.init(title: String(localized: "Local overlays"),
                               icon: "rectangle.inset.topright.fill",
                               destination: .displayLocalOverlays,
                               path: String(localized: "Display")))
            items.append(.init(title: String(localized: "Network interface names"),
                               icon: "rectangle.inset.topright.fill",
                               destination: .displayNetworkInterfaceNames,
                               path: String(localized: "Display")))
        }
        // Camera
        items.append(.init(title: String(localized: "Camera"),
                           icon: "camera", destination: .camera))
        items.append(.init(title: String(localized: "Video"),
                           icon: "camera", destination: .cameraVideo,
                           path: String(localized: "Camera")))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Zoom"),
                               icon: "camera", destination: .cameraZoom,
                               path: String(localized: "Camera")))
            items.append(.init(title: String(localized: "LUTs"),
                               icon: "camera", destination: .cameraLuts,
                               path: String(localized: "Camera")))
        }
        // Audio
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Audio"),
                               icon: "waveform", destination: .audio))
            items.append(.init(title: String(localized: "Mic"),
                               icon: "waveform", destination: .audioMic,
                               path: String(localized: "Audio")))
        }
        // Location
        items.append(.init(title: String(localized: "Location"),
                           icon: "location", destination: .location))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "RealtimeIRL"),
                               icon: "location", destination: .locationRealtimeIrl,
                               path: String(localized: "Location")))
        }
        // Store
        items.append(.init(title: String(localized: "Store (support us) ❤️"),
                           icon: "cart", destination: .store))
        // Ingests
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Ingests"),
                               icon: "server.rack", destination: .ingests))
        }
        // Moblink
        items.append(.init(title: String(localized: "Moblink"),
                           icon: "app.connected.to.app.below.fill", destination: .moblink))
        if database.showAllSettings {
            // Media players, Selfie stick, etc.
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
        // Recordings
        items.append(.init(title: String(localized: "Recordings"),
                           icon: "photo.on.rectangle.angled", destination: .recordings))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "Streaming history"),
                               icon: "text.book.closed", destination: .streamingHistory))
        }
        // Watch
        if database.showAllSettings, isPhone() {
            items.append(.init(title: String(localized: "Apple Watch"),
                               icon: "applewatch", destination: .watch))
            items.append(.init(title: String(localized: "Chat"),
                               icon: "applewatch", destination: .watchChat,
                               path: String(localized: "Apple Watch")))
            items.append(.init(title: String(localized: "Display"),
                               icon: "applewatch", destination: .watchDisplay,
                               path: String(localized: "Apple Watch")))
        }
        // Help, About, Debug
        items.append(.init(title: String(localized: "Help and support"),
                           icon: "questionmark.circle", destination: .helpAndSupport))
        if database.showAllSettings {
            items.append(.init(title: String(localized: "About"),
                               icon: "info.circle", destination: .about))
            items.append(.init(title: String(localized: "Attributions"),
                               icon: "info.circle", destination: .aboutAttributions,
                               path: String(localized: "About")))
            items.append(.init(title: String(localized: "Debug"),
                               icon: "ladybug", destination: .debug))
            items.append(.init(title: String(localized: "Video"),
                               icon: "ladybug", destination: .debugVideo,
                               path: String(localized: "Debug")))
            items.append(.init(title: String(localized: "Import and export settings"),
                               icon: "gearshape", destination: .importExport))
            items.append(.init(title: String(localized: "Deep link creator"),
                               icon: "link.badge.plus", destination: .deepLinkCreator))
        }
        return items
    }

    private var filteredSettingsItems: [SettingsSearchItem] {
        allSettingsItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.path?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
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
        // Chat sub-items
        case .chatBot:
            ChatBotSettingsView()
        case .chatTextToSpeech:
            ChatTextToSpeechSettingsView(chat: database.chat,
                                         ttsMonster: database.chat.ttsMonster)
        // Display sub-items
        case .displayQuickButtons:
            QuickButtonsSettingsView(model: model, showAll: true)
        case .displayStreamButton:
            StreamButtonsSettingsView(database: database)
        case .displayLocalOverlays:
            LocalOverlaysSettingsView(show: database.show)
        case .displayNetworkInterfaceNames:
            LocalOverlaysNetworkInterfaceNamesSettingsView(database: database)
        // Camera sub-items
        case .cameraVideo:
            StreamVideoSettingsView(database: database, stream: model.stream)
        case .cameraZoom:
            ZoomSettingsView(zoom: database.zoom)
        case .cameraLuts:
            CameraSettingsLutsView(color: database.color)
        // Audio sub-items
        case .audioMic:
            QuickButtonMicView(model: model, mics: database.mics, modelMic: model.mic)
        // Location sub-items
        case .locationRealtimeIrl:
            StreamRealtimeIrlSettingsView(stream: model.stream)
        // Debug sub-items
        case .debugVideo:
            DebugVideoSettingsView(debug: database.debug)
        // About sub-items
        case .aboutAttributions:
            AboutAttributionsSettingsView()
        // Watch sub-items
        case .watchChat:
            WatchChatSettingsView(chat: database.watch.chat)
        case .watchDisplay:
            WatchDisplaySettingsView(show: database.watch.show)
        }
    }

    var body: some View {
        Form {
            if isSearching {
                ForEach(filteredSettingsItems) { item in
                    NavigationLink {
                        destinationView(for: item.destination)
                    } label: {
                        if let path = item.path {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                    Text(path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: item.icon)
                            }
                        } else {
                            Label(item.title, systemImage: item.icon)
                        }
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
