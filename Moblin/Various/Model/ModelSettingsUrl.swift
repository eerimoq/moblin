import SwiftUI

extension Model {
    private func handleSettingsUrlsDefaultStreams(settings: MoblinSettingsUrl) {
        var newSelectedStream: SettingsStream?
        for stream in settings.streams ?? [] {
            let existingStream = database.streams.first(where: { $0.name == stream.name })
            let targetStream = existingStream ?? SettingsStream(name: stream.name)
            targetStream.url = stream.url.trim()
            if stream.selected == true {
                newSelectedStream = targetStream
            }
            if let backgroundStreaming = stream.backgroundStreaming {
                targetStream.backgroundStreaming = backgroundStreaming
            }
            if let backgroundStreamingPiP = stream.backgroundStreamingPiP {
                targetStream.backgroundStreamingPiP = backgroundStreamingPiP
            }
            if let video = stream.video {
                if let resolution = video.resolution {
                    targetStream.resolution = resolution
                }
                if let fps = video.fps, fpss.contains(fps) {
                    targetStream.fps = fps
                }
                if let bitrate = video.bitrate, bitrate >= 50000, bitrate <= 50_000_000 {
                    targetStream.bitrate = bitrate
                }
                if let codec = video.codec {
                    targetStream.codec = codec
                }
                if let bFrames = video.bFrames {
                    targetStream.bFrames = bFrames
                }
                if let maxKeyFrameInterval = video.maxKeyFrameInterval, maxKeyFrameInterval >= 0,
                   maxKeyFrameInterval <= 10
                {
                    targetStream.maxKeyFrameInterval = maxKeyFrameInterval
                }
            }
            if let audio = stream.audio {
                if let bitrate = audio.bitrate, isValidAudioBitrate(bitrate: bitrate) {
                    targetStream.audioBitrate = bitrate
                }
            }
            if let srt = stream.srt {
                if let latency = srt.latency {
                    targetStream.srt.latency = latency
                }
                if let adaptiveBitrateEnabled = srt.adaptiveBitrateEnabled {
                    targetStream.srt.adaptiveBitrateEnabled = adaptiveBitrateEnabled
                }
                if let dnsLookupStrategy = srt.dnsLookupStrategy {
                    targetStream.srt.dnsLookupStrategy = dnsLookupStrategy
                }
            }
            if let obs = stream.obs {
                targetStream.obsWebSocketEnabled = true
                targetStream.obsWebSocketUrl = obs.webSocketUrl.trim()
                targetStream.obsWebSocketPassword = obs.webSocketPassword.trim()
            }
            if let twitch = stream.twitch {
                targetStream.twitchChannelName = twitch.channelName.trim()
                targetStream.twitchChannelId = twitch.channelId.trim()
            }
            if let kick = stream.kick {
                targetStream.kickChannelName = kick.channelName.trim()
            }
            if existingStream == nil {
                database.streams.append(targetStream)
            }
        }
        if let newSelectedStream, !isLive, !isRecording {
            setCurrentStream(stream: newSelectedStream)
        }
    }

    private func handleSettingsUrlsDefaultQuickButtons(settings: MoblinSettingsUrl) {
        guard let quickButtons = settings.quickButtons else {
            return
        }
        if let twoColumns = quickButtons.twoColumns {
            database.quickButtonsGeneral.twoColumns = twoColumns
        }
        if let showName = quickButtons.showName {
            database.quickButtonsGeneral.showName = showName
        }
        if let enableScroll = quickButtons.enableScroll {
            database.quickButtonsGeneral.enableScroll = enableScroll
        }
        if quickButtons.disableAllButtons == true {
            for databaseQuickButton in database.quickButtons {
                databaseQuickButton.enabled = false
            }
        }
        for quickButton in quickButtons.buttons ?? [] {
            if let databaseQuickButton = database.quickButtons.first(where: { quickButton.type == $0.type }) {
                if let enabled = quickButton.enabled {
                    databaseQuickButton.enabled = enabled
                }
                if let page = quickButton.page {
                    databaseQuickButton.page = page
                }
            }
        }
    }

    private func handleSettingsUrlsDefaultWebBrowser(settings: MoblinSettingsUrl) {
        guard let webBrowser = settings.webBrowser else {
            return
        }
        if let home = webBrowser.home {
            database.webBrowser.home = home
        }
    }

    private func handleSettingsUrlsDefaultRemoteControl(settings: MoblinSettingsUrl) {
        guard let remoteControl = settings.remoteControl else {
            return
        }
        if let assistant = remoteControl.assistant {
            database.remoteControl.assistant.enabled = assistant.enabled
            database.remoteControl.assistant.port = assistant.port
            if let relay = assistant.relay {
                database.remoteControl.assistant.relay.enabled = relay.enabled
                database.remoteControl.assistant.relay.baseUrl = relay.baseUrl.trim()
                database.remoteControl.assistant.relay.bridgeId = relay.bridgeId.trim()
            }
        }
        if let streamer = remoteControl.streamer {
            database.remoteControl.streamer.enabled = streamer.enabled
            database.remoteControl.streamer.url = streamer.url.trim()
        }
        database.remoteControl.password = remoteControl.password
        reloadRemoteControlStreamer()
        reloadRemoteControlAssistant()
        reloadRemoteControlRelay()
    }

    private func handleSettingsUrlsDefault(settings: MoblinSettingsUrl) {
        handleSettingsUrlsDefaultStreams(settings: settings)
        handleSettingsUrlsDefaultQuickButtons(settings: settings)
        handleSettingsUrlsDefaultWebBrowser(settings: settings)
        handleSettingsUrlsDefaultRemoteControl(settings: settings)
        makeToast(title: String(localized: "URL import successful"))
        updateQuickButtonStates()
    }

    func handleSettingsUrls(urls: Set<UIOpenURLContext>) {
        guard !isLive, !isRecording else {
            makeErrorToast(title: String(localized: "Cannot import settings when live or recording"))
            return
        }
        for url in urls {
            if url.url.isFileURL,
               url.url.pathExtension.caseInsensitiveCompare("moblinSettings") == .orderedSame
            {
                importSettingsWithConfirmation {
                    self.handleSettingsFileImport(url: url.url)
                }
            } else if let message = handleSettingsUrlWithConfirmation(url: url.url) {
                makeErrorToast(
                    title: String(localized: "URL import failed"),
                    subTitle: message
                )
            }
        }
    }

    private func handleSettingsFileImport(url: URL) {
        guard !isLive, !isRecording else {
            return
        }
        _ = url.startAccessingSecurityScopedResource()
        importSettingsFromFile(url: url) {
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func handleSettingsUrlWithConfirmation(url: URL) -> String? {
        guard url.path.isEmpty else {
            return "Custom URL path is not empty"
        }
        guard let query = url.query(percentEncoded: false) else {
            return "Custom URL query is missing"
        }
        let settings: MoblinSettingsUrl
        do {
            settings = try MoblinSettingsUrl.fromString(query: query)
        } catch {
            return error.localizedDescription
        }
        if createStreamWizard.presenting || createStreamWizard.presentingSetup {
            handleSettingsUrlsInWizard(settings: settings)
        } else {
            importSettingsWithConfirmation {
                self.handleSettingsUrlsDefault(settings: settings)
            }
        }
        return nil
    }
}
