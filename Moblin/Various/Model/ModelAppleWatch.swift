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
            let sceneWidgets: [SettingsWidget]
            if let scene = getSelectedScene() {
                sceneWidgets = getSceneWidgets(scene: scene, onlyEnabled: true).map { $0.widget }
            } else {
                sceneWidgets = []
            }
            for id in scoreboardEffects.keys {
                if let scoreboard = sceneWidgets.first(where: { $0.id == id })?.scoreboard {
                    switch scoreboard.type {
                    case .padel:
                        sendUpdatePadelScoreboardToWatch(id: id, padel: scoreboard.padel)
                    case .generic:
                        sendUpdateGenericScoreboardToWatch(id: id, generic: scoreboard.generic)
                    }
                } else {
                    sendRemoveScoreboardToWatch(id: id)
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

    func sendUpdatePadelScoreboardToWatch(id: UUID, padel: SettingsWidgetPadelScoreboard) {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            var home = [padel.homePlayer1]
            var away = [padel.awayPlayer1]
            if padel.type == .doubles {
                home.append(padel.homePlayer2)
                away.append(padel.awayPlayer2)
            }
            let score = padel.score.map { WatchProtocolPadelScoreboardScore(
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

    func sendUpdateGenericScoreboardToWatch(id: UUID, generic: SettingsWidgetGenericScoreboard) {
        guard isWatchReachable() else {
            return
        }
        var data: Data
        do {
            let message = WatchProtocolGenericScoreboard(id: id,
                                                         homeTeam: generic.home,
                                                         awayTeam: generic.away,
                                                         homeScore: generic.score.home,
                                                         awayScore: generic.score.away,
                                                         clockMinutes: generic.clockMinutes,
                                                         clockSeconds: generic.clockSeconds,
                                                         clockMaximum: generic.clockMaximum,
                                                         isClockStopped: generic.isClockStopped,
                                                         title: generic.title)
            data = try JSONEncoder().encode(message)
        } catch {
            return
        }
        sendMessageToWatch(type: .genericScoreboard, data: data)
    }

    func sendRemoveScoreboardToWatch(id: UUID) {
        guard isWatchReachable() else {
            return
        }
        sendMessageToWatch(type: .removeScoreboard, data: id.uuidString)
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
        guard !post.isRedLine() else {
            return
        }
        let displayName = post.displayName(nicknames: database.chat.nicknames,
                                           displayStyle: database.chat.displayStyle)
        let userColor = WatchProtocolColor(
            red: post.userColor.red,
            green: post.userColor.green,
            blue: post.userColor.blue
        )
        let post = WatchProtocolChatMessage(
            id: nextWatchChatPostId,
            timestamp: post.timestamp,
            displayName: displayName,
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
        switch cameraPosition {
        case .front:
            zoomPresets = zoom.frontZoomPresets.map { .init(id: $0.id, name: $0.name) }
        case .back:
            zoomPresets = zoom.backZoomPresets.map { .init(id: $0.id, name: $0.name) }
        default:
            zoomPresets = []
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

    func updateScoreboardEffects() {
        let sceneWidgets: [SettingsWidget]
        if let scene = getSelectedScene() {
            sceneWidgets = getSceneWidgets(scene: scene, onlyEnabled: true).map { $0.widget }
        } else {
            sceneWidgets = []
        }
        for (id, scoreboardEffect) in scoreboardEffects {
            if let scoreboard = sceneWidgets.first(where: { $0.id == id })?.scoreboard {
                switch scoreboard.type {
                case .padel:
                    break
                case .generic:
                    guard let widget = findWidget(id: id) else {
                        continue
                    }
                    guard !widget.scoreboard.generic.isClockStopped else {
                        continue
                    }
                    widget.scoreboard.generic.tickClock()
                    DispatchQueue.main.async {
                        scoreboardEffect.update(scoreboard: widget.scoreboard, players: self.database.scoreboardPlayers)
                    }
                    sendUpdateGenericScoreboardToWatch(id: id, generic: scoreboard.generic)
                }
            }
        }
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
                    _ = self.stopStream()
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

    private func handleSkipCurrentChatTextToSpeechMessage() {
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
        guard let action = try? JSONDecoder().decode(WatchProtocolPadelScoreboardAction.self, from: data) else {
            return
        }
        DispatchQueue.main.async {
            guard self.isWatchLocal() else {
                return
            }
            guard let widget = self.findWidget(id: action.id) else {
                return
            }
            switch action.action {
            case .reset:
                self.handleUpdatePadelScoreboardReset(scoreboard: widget.scoreboard.padel)
            case .undo:
                self.handleUpdatePadelScoreboardUndo(scoreboard: widget.scoreboard.padel)
            case .incrementHome:
                self.handleUpdatePadelScoreboardIncrementHome(scoreboard: widget.scoreboard.padel)
            case .incrementAway:
                self.handleUpdatePadelScoreboardIncrementAway(scoreboard: widget.scoreboard.padel)
            case let .players(players):
                self.handleUpdatePadelScoreboardChangePlayers(scoreboard: widget.scoreboard.padel,
                                                              players: players)
            }
            guard let scoreboardEffect = self.scoreboardEffects[action.id] else {
                return
            }
            scoreboardEffect.update(scoreboard: widget.scoreboard, players: self.database.scoreboardPlayers)
            self.sendUpdatePadelScoreboardToWatch(id: action.id, padel: widget.scoreboard.padel)
        }
    }

    private func handleUpdatePadelScoreboardReset(scoreboard: SettingsWidgetPadelScoreboard) {
        scoreboard.score = [.init()]
        scoreboard.scoreChanges.removeAll()
    }

    private func handleUpdatePadelScoreboardUndo(scoreboard: SettingsWidgetPadelScoreboard) {
        guard let team = scoreboard.scoreChanges.popLast() else {
            return
        }
        guard let score = scoreboard.score.last else {
            return
        }
        if score.home == 0, score.away == 0, scoreboard.score.count > 1 {
            scoreboard.score.removeLast()
        }
        let index = scoreboard.score.count - 1
        switch team {
        case .home:
            if scoreboard.score[index].home > 0 {
                scoreboard.score[index].home -= 1
            }
        case .away:
            if scoreboard.score[index].away > 0 {
                scoreboard.score[index].away -= 1
            }
        }
    }

    private func handleUpdatePadelScoreboardIncrementHome(scoreboard: SettingsWidgetPadelScoreboard) {
        if !isCurrentSetCompleted(scoreboard: scoreboard) {
            guard !isMatchCompleted(scoreboard: scoreboard) else {
                return
            }
            scoreboard.score[scoreboard.score.count - 1].home += 1
            scoreboard.scoreChanges.append(.home)
        } else {
            padelScoreboardUpdateSetCompleted(scoreboard: scoreboard)
        }
    }

    private func handleUpdatePadelScoreboardIncrementAway(scoreboard: SettingsWidgetPadelScoreboard) {
        if !isCurrentSetCompleted(scoreboard: scoreboard) {
            guard !isMatchCompleted(scoreboard: scoreboard) else {
                return
            }
            scoreboard.score[scoreboard.score.count - 1].away += 1
            scoreboard.scoreChanges.append(.away)
        } else {
            padelScoreboardUpdateSetCompleted(scoreboard: scoreboard)
        }
    }

    private func handleUpdatePadelScoreboardChangePlayers(scoreboard: SettingsWidgetPadelScoreboard,
                                                          players: WatchProtocolPadelScoreboardActionPlayers)
    {
        if players.home.count > 0 {
            scoreboard.homePlayer1 = players.home[0]
            if players.home.count > 1 {
                scoreboard.homePlayer2 = players.home[1]
            }
        }
        if players.away.count > 0 {
            scoreboard.awayPlayer1 = players.away[0]
            if players.away.count > 1 {
                scoreboard.awayPlayer2 = players.away[1]
            }
        }
    }

    private func handleUpdateGenericScoreboard(_ data: Any) {
        guard let data = data as? Data else {
            return
        }
        guard let action = try? JSONDecoder().decode(WatchProtocolGenericScoreboardAction.self, from: data) else {
            return
        }
        DispatchQueue.main.async {
            guard self.isWatchLocal() else {
                return
            }
            guard let widget = self.findWidget(id: action.id) else {
                return
            }
            switch action.action {
            case .reset:
                self.handleUpdateGenericScoreboardReset(scoreboard: widget.scoreboard.generic)
            case .undo:
                self.handleUpdateGenericScoreboardUndo(scoreboard: widget.scoreboard.generic)
            case .incrementHome:
                self.handleUpdateGenericScoreboardIncrementHome(scoreboard: widget.scoreboard.generic)
            case .incrementAway:
                self.handleUpdateGenericScoreboardIncrementAway(scoreboard: widget.scoreboard.generic)
            case let .setTitle(title):
                self.handleUpdateGenericScoreboardSetTitle(scoreboard: widget.scoreboard.generic, title: title)
            case let .setClock(minutes, seconds):
                self.handleUpdateGenericScoreboardSetClock(scoreboard: widget.scoreboard.generic,
                                                           minutes: minutes,
                                                           seconds: seconds)
            case let .setClockState(stopped: stopped):
                self.handleUpdateGenericScoreboardSetClockState(scoreboard: widget.scoreboard.generic,
                                                                stopped: stopped)
            }
            guard let scoreboardEffect = self.scoreboardEffects[action.id] else {
                return
            }
            scoreboardEffect.update(scoreboard: widget.scoreboard, players: self.database.scoreboardPlayers)
            self.sendUpdateGenericScoreboardToWatch(id: action.id, generic: widget.scoreboard.generic)
        }
    }

    private func handleUpdateGenericScoreboardReset(scoreboard: SettingsWidgetGenericScoreboard) {
        scoreboard.score.home = 0
        scoreboard.score.away = 0
        scoreboard.scoreChanges.removeAll()
    }

    private func handleUpdateGenericScoreboardUndo(scoreboard: SettingsWidgetGenericScoreboard) {
        guard let team = scoreboard.scoreChanges.popLast() else {
            return
        }
        switch team {
        case .home:
            if scoreboard.score.home > 0 {
                scoreboard.score.home -= 1
            }
        case .away:
            if scoreboard.score.away > 0 {
                scoreboard.score.away -= 1
            }
        }
    }

    private func handleUpdateGenericScoreboardIncrementHome(scoreboard: SettingsWidgetGenericScoreboard) {
        scoreboard.score.home += 1
        scoreboard.scoreChanges.append(.home)
    }

    private func handleUpdateGenericScoreboardIncrementAway(scoreboard: SettingsWidgetGenericScoreboard) {
        scoreboard.score.away += 1
        scoreboard.scoreChanges.append(.away)
    }

    private func handleUpdateGenericScoreboardSetTitle(scoreboard: SettingsWidgetGenericScoreboard,
                                                       title: String)
    {
        scoreboard.title = title
    }

    private func handleUpdateGenericScoreboardSetClock(scoreboard: SettingsWidgetGenericScoreboard,
                                                       minutes: Int,
                                                       seconds: Int)
    {
        scoreboard.clockMinutes = minutes.clamped(to: 0 ... scoreboard.clockMaximum)
        if scoreboard.clockMinutes == scoreboard.clockMaximum {
            scoreboard.clockSeconds = 0
        } else {
            scoreboard.clockSeconds = seconds.clamped(to: 0 ... 59)
        }
    }

    private func handleUpdateGenericScoreboardSetClockState(scoreboard: SettingsWidgetGenericScoreboard,
                                                            stopped: Bool)
    {
        scoreboard.isClockStopped = stopped
    }

    private func padelScoreboardUpdateSetCompleted(scoreboard: SettingsWidgetPadelScoreboard) {
        guard let score = scoreboard.score.last else {
            return
        }
        guard isSetCompleted(score: score) else {
            return
        }
        guard !isMatchCompleted(scoreboard: scoreboard) else {
            return
        }
        scoreboard.score.append(.init())
    }

    private func isCurrentSetCompleted(scoreboard: SettingsWidgetPadelScoreboard) -> Bool {
        guard let score = scoreboard.score.last else {
            return false
        }
        return isSetCompleted(score: score)
    }

    private func isSetCompleted(score: SettingsWidgetScoreboardScore) -> Bool {
        let maxScore = max(score.home, score.away)
        let minScore = min(score.home, score.away)
        if maxScore == 6 && minScore <= 4 {
            return true
        }
        if maxScore == 7 {
            return true
        }
        return false
    }

    private func isMatchCompleted(scoreboard: SettingsWidgetPadelScoreboard) -> Bool {
        if scoreboard.score.count < 5 {
            return false
        }
        guard let score = scoreboard.score.last else {
            return false
        }
        return isSetCompleted(score: score)
    }

    private func handleCreateStreamMarker() {
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.createStreamMarker()
            }
        }
    }

    private func handleInstantReplay(_ data: Any) {
        guard let data = data as? Data else {
            return
        }
        guard let instantReplay = try? JSONDecoder().decode(WatchProtocolInstantReplay.self, from: data) else {
            return
        }
        DispatchQueue.main.async {
            if self.isWatchLocal() {
                self.instantReplay(start: SettingsReplay.stop - Double(instantReplay.duration), delay: 1)
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
            handleSkipCurrentChatTextToSpeechMessage()
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
        case .updateGenericScoreboard:
            handleUpdateGenericScoreboard(data)
        case .createStreamMarker:
            handleCreateStreamMarker()
        case .instantReplay:
            handleInstantReplay(data)
        case .saveReplay:
            handleSaveReplay()
        case .getImage:
            break
        }
    }
}
