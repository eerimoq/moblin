import SwiftUI

private struct SettingsSearchDestinationView: View {
    @EnvironmentObject var model: Model
    let page: SettingsSearchPage

    private var database: Database {
        model.database
    }

    private var stream: SettingsStream {
        model.stream
    }

    var body: some View {
        switch page {
        case .streams:
            StreamsSettingsView(createStreamWizard: model.createStreamWizard, database: database)
        case .stream:
            StreamSettingsView(database: database, stream: stream)
        case .streamUrl:
            StreamUrlSettingsView(stream: stream)
        case .streamSrt:
            StreamSrtSettingsView(stream: stream, srt: stream.srt)
        case .streamRtmp:
            StreamRtmpSettingsView(stream: stream)
        case .streamRist:
            StreamRistSettingsView(stream: stream)
        case .streamWhip:
            StreamWhipSettingsView(model: model, stream: stream, whip: stream.whip)
        case .streamMobcam:
            StreamMobcamSettingsView(stream: stream)
        case .streamVideo:
            StreamVideoSettingsView(database: database, stream: stream)
        case .streamAudio:
            StreamAudioSettingsView(stream: stream, bitrate: Float(stream.audioBitrate / 1000))
        case .streamRecording:
            StreamRecordingSettingsView(stream: stream, recording: stream.recording)
        case .streamReplay:
            StreamReplaySettingsView(database: database, stream: stream, replay: stream.replay)
        case .streamSnapshot:
            StreamSnapshotSettingsView(model: model, stream: stream, recording: stream.recording)
        case .streamPreviewStream:
            StreamPreviewStreamSettingsView(previewStream: stream.previewStream)
        case .streamTwitch:
            StreamTwitchSettingsView(stream: stream, loggedIn: stream.twitchLoggedIn)
        case .streamKick:
            StreamKickSettingsView(model: model, stream: stream)
        case .streamYouTube:
            StreamYouTubeSettingsView(debug: database.debug, stream: stream)
        case .streamSoop:
            StreamSoopSettingsView(stream: stream)
        case .streamOpenStreamingPlatform:
            StreamOpenStreamingPlatformSettingsView(stream: stream)
        case .streamObsRemoteControl:
            StreamObsRemoteControlSettingsView(stream: stream)
        case .streamGoLiveNotification:
            GoLiveNotificationSettingsView(stream: stream)
        case .streamRealtimeIrl:
            StreamRealtimeIrlSettingsView(model: model, stream: stream)
        case .streamEmotes:
            StreamEmotesSettingsView(stream: stream)
        case .scenes:
            ScenesSettingsView(model: model, database: database)
        case .chat:
            ChatSettingsView(model: model, database: database, chat: database.chat, stream: stream)
        case .chatBot:
            ChatBotSettingsView()
        case .chatTextToSpeech:
            ChatTextToSpeechSettingsView(model: model,
                                         chat: database.chat,
                                         ttsMonster: database.chat.ttsMonster,
                                         elevenLabs: database.chat.elevenLabs)
        case .display:
            DisplaySettingsView(database: database)
        case .displayQuickButtons:
            QuickButtonsSettingsView(model: model, showAll: true)
        case .displayStreamButton:
            StreamButtonsSettingsView(database: database)
        case .displayLocalOverlays:
            LocalOverlaysSettingsView(show: database.show)
        case .displayNetworkInterfaceNames:
            LocalOverlaysNetworkInterfaceNamesSettingsView(model: model, database: database)
        case .camera:
            CameraSettingsView(database: database, stream: stream, color: database.color)
        case .cameraZoom:
            ZoomSettingsView(zoom: database.zoom)
        case .cameraLuts:
            CameraSettingsLutsView(color: database.color)
        case .audio:
            AudioSettingsView(database: database,
                              stream: stream,
                              mic: model.mic,
                              debug: database.debug,
                              audio: database.audio)
        case .audioDelays:
            MicsDelaySettingsView(model: model, mics: database.mics)
        case .audioGains:
            MicsGainSettingsView(model: model, mics: database.mics)
        case .macros:
            MacrosSettingsView(model: model, database: database, macros: database.macros)
        case .location:
            LocationSettingsView(database: database,
                                 location: database.location,
                                 locationManager: model.locationManager,
                                 stream: $model.stream)
        case .store:
            StoreSettingsView(model: model, store: model.store)
        case .ingests:
            IngestsSettingsView(model: model, database: database)
        case .talkback:
            TalkbackSettingsView(model: model, mics: database.mics, talkback: database.talkback)
        case .moblink:
            MoblinkSettingsView(status: model.statusOther, streamer: database.moblink.streamer)
        case .mediaPlayers:
            MediaPlayersSettingsView(model: model, mediaPlayers: database.mediaPlayers)
        case .appleMusic:
            AppleMusicSettingsView(model: model, musicPlaylist: model.musicPlaylist)
        case .gimbal:
            GimbalSettingsView(model: model, gimbal: database.gimbal)
        case .selfieStick:
            SelfieStickSettingsView(model: model, selfieStick: database.selfieStick)
        case .gameControllers:
            GameControllersSettingsView(model: model, database: database)
        case .keyboard:
            if #available(iOS 17.0, *) {
                KeyboardSettingsView(model: model, keyboard: database.keyboard)
            }
        case .streamDecks:
            #if !targetEnvironment(macCatalyst)
            StreamDecksSettingsView(model: model,
                                    streamDeck: model.streamDeck,
                                    streamDecks: database.streamDecks)
            #else
            EmptyView()
            #endif
        case .remoteControl:
            RemoteControlSettingsView(database: database, stream: $model.stream)
        case .moblinCloud:
            MoblinCloudSettingsView(model: model, database: database, moblinCloud: database.moblinCloud)
        case .djiDevices:
            DjiDevicesSettingsView(model: model, djiDevices: database.djiDevices)
        case .goPro:
            GoProSettingsView()
        case .catPrinters:
            CatPrintersSettingsView(model: model, catPrinters: database.catPrinters)
        case .tesla:
            TeslaSettingsView(tesla: model.tesla)
        case .workoutDevices:
            WorkoutDevicesSettingsView(model: model, workoutDevices: database.workoutDevices)
        case .blackSharkCoolers:
            BlackSharkCoolerDevicesSettingsView(model: model,
                                                blackSharkCoolerDevices: database.blackSharkCoolerDevices)
        case .recordings:
            RecordingsSettingsView(model: model)
        case .streamingHistory:
            StreamingHistorySettingsView(model: model)
        case .watch:
            WatchSettingsView(model: model, watch: database.watch)
        case .watchChat:
            WatchChatSettingsView(model: model, chat: database.watch.chat)
        case .watchDisplay:
            WatchDisplaySettingsView(show: database.watch.show)
        case .watchLocalOverlays:
            WatchLocalOverlaysSettingsView(show: database.watch.show)
        case .helpAndSupport:
            HelpAndSupportSettingsView()
        case .about:
            AboutSettingsView()
        case .aboutAttributions:
            AboutAttributionsSettingsView()
        case .debug:
            DebugSettingsView(model: model, debug: database.debug)
        case .debugVideo:
            DebugVideoSettingsView(model: model, debug: database.debug)
        case .debugHttpProxy:
            HttpProxySettingsView(model: model, status: model.statusOther, httpProxy: database.httpProxy)
        case .importExport:
            ImportExportSettingsView(model: model)
        case .deepLinkCreator:
            DeepLinkCreatorSettingsView(deepLinkCreator: database.deepLinkCreator)
        }
    }
}

struct SettingsSearchResultsView: View {
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream
    let text: String

    var body: some View {
        let results = searchSettings(text: text,
                                     nodes: settingsSearchNodes(stream: stream),
                                     database: database)
        Section {
            if results.isEmpty {
                Text("No results")
            } else {
                ForEach(results) { result in
                    NavigationLink {
                        SettingsSearchDestinationView(page: result.page)
                    } label: {
                        HStack {
                            Image(systemName: result.image)
                                .frame(width: iconWidth)
                            VStack(alignment: .leading) {
                                Text(result.title)
                                if !result.path.isEmpty {
                                    Text(result.path)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
