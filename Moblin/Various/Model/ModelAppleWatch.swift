import UIKit
import WatchConnectivity

extension Model {
    func isWatchReachable() -> Bool {
        return WCSession.default.activationState == .activated && WCSession.default.isReachable
    }

    private func sendMessageToWatch(
        type: WatchMessageToWatch,
        data: Any,
        replyHandler: (([String: Any]) -> Void)? = nil,
        errorHandler: ((Error) -> Void)? = nil
    ) {
        WCSession.default.sendMessage(
            WatchMessageToWatch.pack(type: type, data: data),
            replyHandler: replyHandler,
            errorHandler: errorHandler
        )
    }

    func sendInitToWatch() {
        setLowFpsImage()
        sendSettingsToWatch()
        if !isWatchReachable() {
            remoteControlAssistantStopPreview(user: .watch)
        }
        if isWatchRemoteControl() {
            if isWatchReachable() {
                remoteControlAssistantStartPreview(user: .watch)
            }
            sendRemoteControlAssistantStatusToWatch()
        } else {
            sendZoomToWatch(x: zoom.x)
            sendZoomPresetsToWatch()
            sendZoomPresetToWatch()
            sendScenesToWatchLocal()
            sendSceneToWatch(id: sceneSelector.selectedSceneId)
            sendWorkoutToWatch()
            resetWorkoutStats()
            trySendNextChatPostToWatch()
            sendAudioLevelToWatch(audioLevel: audio.level.level)
            sendThermalStateToWatch(thermalState: statusOther.thermalState)
            sendIsLiveToWatch(isLive: isLive)
            sendIsRecordingToWatch(isRecording: isRecording)
            sendIsMutedToWatch(isMuteOn: isMuteOn)
            sendViewerCountWatch()
            sendScoreboardPlayersToWatch()
            let sceneWidgets = getSelectedScene()?.widgets ?? []
            for id in padelScoreboardEffects.keys {
                if let sceneWidget = sceneWidgets.first(where: { $0.widgetId == id }),
                   sceneWidget.enabled,
                   let scoreboard = findWidget(id: id)?.scoreboard
                {
                    sendUpdatePadelScoreboardToWatch(id: id, scoreboard: scoreboard)
                } else {
                    sendRemovePadelScoreboardToWatch(id: id)
                }
            }
        }
    }

    func sendSpeedAndTotalToWatch(speedAndTotal: String) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .speedAndTotal, data: speedAndTotal)
    }

    func sendRecordingLengthToWatch(recordingLength: String) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .recordingLength, data: recordingLength)
    }

    func sendAudioLevelToWatch(audioLevel: Float) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .audioLevel, data: audioLevel)
    }

    func sendThermalStateToWatch(thermalState: ProcessInfo.ThermalState) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .thermalState, data: thermalState.rawValue)
    }

    private func sendStartWorkoutToWatch(type: WatchProtocolWorkoutType) {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            let message = WatchProtocolStartWorkout(type: type)
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        sendMessageToWatch(type: .startWorkout, data: data)
    }

    private func sendStopWorkoutToWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .stopWorkout, data: true)
    }

    func sendWorkoutToWatch() {
        if let workoutType {
            sendStartWorkoutToWatch(type: workoutType)
        } else {
            sendStopWorkoutToWatch()
        }
    }

    func sendViewerCountWatch() {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .viewerCount, data: statusTopLeft.numberOfViewers)
    }

    func sendUpdatePadelScoreboardToWatch(id: UUID, scoreboard: SettingsWidgetScoreboard) {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            var home = [scoreboard.padel.homePlayer1]
            var away = [scoreboard.padel.awayPlayer1]
            if scoreboard.padel.type == .doubles {
                home.append(scoreboard.padel.homePlayer2)
                away.append(scoreboard.padel.awayPlayer2)
            }
            let score = scoreboard.padel.score.map { WatchProtocolPadelScoreboardScore(
                home: $0.home,
                away: $0.away
            ) }
            let message = WatchProtocolPadelScoreboard(id: id, home: home, away: away, score: score)
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        sendMessageToWatch(type: .padelScoreboard, data: data)
    }

    func sendRemovePadelScoreboardToWatch(id: UUID) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .removePadelScoreboard, data: id.uuidString)
    }

    func sendScoreboardPlayersToWatch() {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            let message = database.scoreboardPlayers.map { WatchProtocolScoreboardPlayer(
                id: $0.id,
                name: $0.name
            ) }
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        sendMessageToWatch(type: .scoreboardPlayers, data: data)
    }

    private func resetWorkoutStats() {
        heartRates.removeAll()
        workoutActiveEnergyBurned = nil
        workoutDistance = nil
        workoutPower = nil
        workoutStepCount = nil
    }

    private func enqueueWatchChatPost(post: ChatPost) {
        guard WCSession.default.isWatchAppInstalled else {
            return
        }
        guard let user = post.user else {
            return
        }
        let userColor = WatchProtocolColor(
            red: post.userColor.red,
            green: post.userColor.green,
            blue: post.userColor.blue
        )
        let post = WatchProtocolChatMessage(
            id: nextWatchChatPostId,
            timestamp: post.timestamp,
            user: user,
            userColor: userColor,
            userBadges: post.userBadges,
            segments: post.segments
                .map { WatchProtocolChatSegment(text: $0.text, url: $0.url?.absoluteString) },
            highlight: post.highlight?.toWatchProtocol()
        )
        nextWatchChatPostId += 1
        watchChatPosts.append(post)
        if watchChatPosts.count > maximumNumberOfWatchChatMessages {
            _ = watchChatPosts.popFirst()
        }
    }

    func trySendNextChatPostToWatch() {
        guard isWatchReachable(), let post = watchChatPosts.popFirst() else {
            return
        }
        var data: Data
        do {
            data = try JSONEncoder().encode(post)
        } catch {
            logger.info("watch: Chat message send failed")
            return
        }
        sendMessageToWatch(type: .chatMessage, data: data)
    }

    func sendChatMessageToWatch(post: ChatPost) {
        enqueueWatchChatPost(post: post)
    }

    func sendPreviewToWatch(image: Data) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .preview, data: image)
    }

    func sendZoomToWatch(x: Float) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .zoom, data: x)
    }

    func sendZoomPresetsToWatch() {
        guard isWatchReachable() else {
            return
        }
        let zoomPresets: [WatchProtocolZoomPreset]
        if cameraPosition == .front {
            zoomPresets = frontZoomPresets().map { .init(id: $0.id, name: $0.name) }
        } else {
            zoomPresets = backZoomPresets().map { .init(id: $0.id, name: $0.name) }
        }
        do {
            let zoomPresets = try JSONEncoder().encode(zoomPresets)
            sendMessageToWatch(type: .zoomPresets, data: zoomPresets)
        } catch {}
    }

    func sendZoomPresetToWatch() {
        guard isWatchReachable() else {
            return
        }
        let zoomPreset: UUID
        if cameraPosition == .front {
            zoomPreset = zoom.frontPresetId
        } else {
            zoomPreset = zoom.backPresetId
        }
        sendMessageToWatch(type: .zoomPreset, data: zoomPreset.uuidString)
    }

    private func sendScenesToWatch(scenes: [WatchProtocolScene]) {
        guard isWatchReachable() else {
            return
        }
        do {
            try sendMessageToWatch(type: .scenes, data: JSONEncoder().encode(scenes))
        } catch {}
    }

    private func sendScenesToWatchLocal() {
        sendScenesToWatch(scenes: enabledScenes.map { WatchProtocolScene(id: $0.id, name: $0.name) })
    }

    private func sendScenesToWatchRemoteControl() {
        guard let scenes = remoteControl.settings?.scenes else {
            return
        }
        sendScenesToWatch(scenes: scenes.map { WatchProtocolScene(id: $0.id, name: $0.name) })
    }

    func sendSceneToWatch(id: UUID) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .scene, data: id.uuidString)
    }

    func sendSettingsToWatch() {
        guard isWatchReachable() else {
            return
        }
        do {
            let settings = try JSONEncoder().encode(database.watch)
            sendMessageToWatch(type: .settings, data: settings)
        } catch {}
    }

    func sendIsLiveToWatch(isLive: Any) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isLive, data: isLive)
    }

    func sendIsRecordingToWatch(isRecording: Any) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isRecording, data: isRecording)
    }

    func sendIsMutedToWatch(isMuteOn: Any) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .isMuted, data: isMuteOn)
    }

    func sendRemoteControlAssistantStatusToWatch() {
        if let general = remoteControl.general {
            if let thermalState = general.flame?.toThermalState() {
                sendThermalStateToWatch(thermalState: thermalState)
            }
            if let isLive = general.isLive {
                sendIsLiveToWatch(isLive: isLive)
            }
            if let isRecording = general.isRecording {
                sendIsRecordingToWatch(isRecording: isRecording)
            }
            if let isMuted = general.isMuted {
                sendIsMutedToWatch(isMuteOn: isMuted)
            }
        }
        if let topLeft = remoteControl.topLeft {
            if let zoom = topLeft.zoom {
                sendZoomToWatch(x: Float(zoom.message) ?? 0.0)
            }
        }
        if let topRight = remoteControl.topRight {
            if let recordingMessage = topRight.recording?.message {
                sendRecordingLengthToWatch(recordingLength: recordingMessage)
            }
            if let bitrateMessage = topRight.bitrate?.message {
                sendSpeedAndTotalToWatch(speedAndTotal: bitrateMessage)
            }
            if let audioInfo = topRight.audioInfo {
                sendAudioLevelToWatch(audioLevel: audioInfo.audioLevel.toFloat())
            }
        }
        sendScenesToWatchRemoteControl()
        sendSceneToWatch(id: remoteControl.scene)
    }

    func isWatchRemoteControl() -> Bool {
        return database.watch.viaRemoteControl
    }

    func isWatchLocal() -> Bool {
        return !isWatchRemoteControl()
    }
}

extension Model: WCSessionDelegate {
    func session(
        _: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error _: Error?
    ) {
        logger.debug("watch: \(activationState)")
        switch activationState {
        case .activated:
            DispatchQueue.main.async {
                self.setLowFpsImage()
                if self.isWatchLocal() {
                    self.sendWorkoutToWatch()
                }
            }
        default:
            break
        }
    }

    func sessionDidBecomeInactive(_: WCSession) {
        logger.debug("watch: Session inactive")
    }

    func sessionDidDeactivate(_: WCSession) {
        logger.debug("watch: Session deactive")
    }

    func sessionReachabilityDidChange(_: WCSession) {
        logger.debug("watch: Reachability changed to \(isWatchReachable())")
        DispatchQueue.main.async {
            self.sendInitToWatch()
        }
    }

    private func makePng(_ uiImage: UIImage) -> Data {
        for height in [35.0, 25.0, 15.0] {
            guard let pngData = uiImage.resize(height: height).pngData() else {
                return Data()
            }
            if pngData.count < 15000 {
                return pngData
            }
        }
        return Data()
    }

    private func handleGetImage(_ data: Any, _ replyHandler: @escaping ([String: Any]) -> Void) {
        guard let urlString = data as? String else {
            replyHandler(["data": Data()])
            return
        }
        guard let url = URL(string: urlString) else {
            replyHandler(["data": Data()])
            return
        }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, _ in
            guard let response = response?.http else {
                replyHandler(["data": Data()])
                return
            }
            guard response.isSuccessful, let data else {
                replyHandler(["data": Data()])
                return
            }
            guard let uiImage = UIImage(data: data) else {
                replyHandler(["data": Data()])
                return
            }
            replyHandler(["data": self.makePng(uiImage)])
        }
        .resume()
    }

    private func handleSetIsLive(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchRemoteControl() {
                self.remoteControlAssistantSetStream(on: value)
            } else {
                if value {
                    self.startStream()
                } else {
                    self.stopStream()
                }
            }
        }
    }

    private func handleSetIsRecording(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchRemoteControl() {
                self.remoteControlAssistantSetRecord(on: value)
            } else {
                if value {
                    self.startRecording()
                } else {
                    self.stopRecording()
                }
            }
        }
    }

    private func handleSetIsMuted(_ data: Any) {
        guard let value = data as? Bool else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchRemoteControl() {
                self.remoteControlAssistantSetMute(on: value)
            } else {
                self.setIsMuted(value: value)
            }
        }
    }

    private func handleSkipCurrentChatTextToSpeechMessage(_: Any) {
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.chatTextToSpeech.skipCurrentMessage()
            }
        }
    }

    private func handleSetZoomMessage(_ data: Any) {
        guard let x = data as? Float else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.setZoomX(x: x, rate: self.database.zoom.speed)
            } else {
                self.remoteControlAssistantSetZoom(x: x)
            }
        }
    }

    private func handleSetZoomPresetMessage(_ data: Any) {
        guard let data = data as? String else {
            return
        }
        guard let zoomPresetId = UUID(uuidString: data) else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.setZoomPreset(id: zoomPresetId)
            }
        }
    }

    private func handleSetSceneMessage(_ data: Any) {
        guard let data = data as? String else {
            return
        }
        guard let sceneId = UUID(uuidString: data) else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.selectScene(id: sceneId)
            } else {
                self.remoteControlAssistantSetScene(id: sceneId)
            }
        }
    }

    private func handleUpdateWorkoutStats(_ data: Any) {
        guard let data = data as? Data else {
            return
        }
        guard let stats = try? JSONDecoder().decode(WatchProtocolWorkoutStats.self, from: data) else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                if let heartRate = stats.heartRate {
                    self.heartRates[""] = heartRate
                }
                if let activeEnergyBurned = stats.activeEnergyBurned {
                    self.workoutActiveEnergyBurned = activeEnergyBurned
                }
                if let distance = stats.distance {
                    self.workoutDistance = distance
                }
                if let stepCount = stats.stepCount {
                    self.workoutStepCount = stepCount
                }
                if let power = stats.power {
                    self.workoutPower = power
                }
            }
        }
    }

    private func handleUpdatePadelScoreboard(_ data: Any) {
        guard let data = data as? Data else {
            return
        }
        guard let scoreboard = try? JSONDecoder().decode(WatchProtocolPadelScoreboard.self, from: data) else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                guard let widget = self.findWidget(id: scoreboard.id) else {
                    return
                }
                widget.scoreboard.padel.score = scoreboard.score.map {
                    let score = SettingsWidgetScoreboardScore()
                    score.home = $0.home
                    score.away = $0.away
                    return score
                }
                widget.scoreboard.padel.homePlayer1 = scoreboard.home[0]
                if scoreboard.home.count > 1 {
                    widget.scoreboard.padel.homePlayer2 = scoreboard.home[1]
                }
                widget.scoreboard.padel.awayPlayer1 = scoreboard.away[0]
                if scoreboard.away.count > 1 {
                    widget.scoreboard.padel.awayPlayer2 = scoreboard.away[1]
                }
                guard let padelScoreboardEffect = self.padelScoreboardEffects[scoreboard.id] else {
                    return
                }
                padelScoreboardEffect
                    .update(scoreboard: self.padelScoreboardSettingsToEffect(widget.scoreboard.padel))
            }
        }
    }

    private func handleCreateStreamMarker() {
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.createStreamMarker()
            }
        }
    }

    private func handleInstantReplay() {
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.instantReplay()
            } else {
                logger.info("Instant replay via remote control not yet supported.")
            }
        }
    }

    private func handleSaveReplay() {
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                _ = self.saveReplay()
            } else {
                logger.info("Save replay via remote control not yet supported.")
            }
        }
    }

    func session(
        _: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let (type, data) = WatchMessageFromWatch.unpack(message) else {
            logger.info("watch: Invalid message")
            replyHandler([:])
            return
        }
        switch type {
        case .getImage:
            handleGetImage(data, replyHandler)
        default:
            replyHandler([:])
        }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let (type, data) = WatchMessageFromWatch.unpack(message) else {
            logger.info("watch: Invalid message")
            return
        }
        switch type {
        case .setIsLive:
            handleSetIsLive(data)
        case .setIsRecording:
            handleSetIsRecording(data)
        case .setIsMuted:
            handleSetIsMuted(data)
        case .keepAlive:
            break
        case .skipCurrentChatTextToSpeechMessage:
            handleSkipCurrentChatTextToSpeechMessage(data)
        case .setZoom:
            handleSetZoomMessage(data)
        case .setZoomPreset:
            handleSetZoomPresetMessage(data)
        case .setScene:
            handleSetSceneMessage(data)
        case .updateWorkoutStats:
            handleUpdateWorkoutStats(data)
        case .updatePadelScoreboard:
            handleUpdatePadelScoreboard(data)
        case .createStreamMarker:
            handleCreateStreamMarker()
        case .instantReplay:
            handleInstantReplay()
        case .saveReplay:
            handleSaveReplay()
        case .getImage:
            break
        }
    }
}
