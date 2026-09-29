import AVFAudio
import SwiftUI

@MainActor
class AudioLevel: ObservableObject {
    @Published var level: Float = defaultAudioLevel
}

@MainActor
class AudioProvider: ObservableObject {
    let level = AudioLevel()
    @Published var muted: Bool = false
    @Published var numberOfChannels: Int = 0
    @Published var sampleRate: Double = 0
}

@MainActor
class Mic: ObservableObject {
    @Published var current: SettingsMicsMic = noMic
    @Published var inputGain: Float = 1.0
    @Published var inputGainSettable: Bool = false
    let inputGainTimer = SimpleTimer(queue: processorControlQueue)
    var requested: SettingsMicsMic?
    var isSwitchTimerRunning: Bool = false
}

extension Model {
    func setupInputGainObserver() {
        inputGainObservation = AVAudioSession.sharedInstance().observe(\.inputGain) { session, _ in
            DispatchQueue.main.async {
                self.mic.inputGain = session.inputGain
            }
        }
    }

    func setupAudio() {
        updateMics()
        if database.mics.defaultMic.isEmpty {
            database.mics.defaultMic = database.mics.mics
                .first(where: { $0.builtInOrientation == database.mic })?
                .id ?? ""
        }
        if let mic = getConnectedMicById(id: database.mics.defaultMic) {
            defaultMic = mic
        } else {
            defaultMic = getHighestPriorityConnectedMic() ?? noMic
        }
        if let scene = getSelectedScene(), scene.overrideMic, let mic = getConnectedMicById(id: scene.micId) {
            selectMic(mic: mic)
        } else {
            selectMic(mic: defaultMic)
        }
    }

    func setupAudioAfterSettingsImport() {
        mic.current = noMic
        setupAudio()
    }

    func reloadAudioSession() {
        teardownAudioSession()
        setupAudioSession()
        guard !isChatPhone() else {
            return
        }
        media.attachDefaultAudioDevice(builtinDelay: database.debug.builtinAudioAndVideoDelay)
    }

    func setInputGainIfSupported(inputGain: Float) {
        mic.inputGainTimer.startSingleShot(timeout: 0.5) {
            let session = AVAudioSession.sharedInstance()
            guard session.isInputGainSettable, inputGain != session.inputGain else {
                return
            }
            try? session.setInputGain(inputGain)
        }
    }

    func setupAudioSession() {
        let bluetoothOutputOnly = database.debug.bluetoothOutputOnly
        let chatPhone = isChatPhone()
        processorControlQueue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                let bluetoothOption: AVAudioSession.CategoryOptions
                if bluetoothOutputOnly {
                    bluetoothOption = .allowBluetoothA2DP
                } else {
                    #if targetEnvironment(macCatalyst)
                    bluetoothOption = .allowBluetoothHFP
                    #else
                    if #available(iOS 26, *) {
                        bluetoothOption = [.allowBluetoothHFP, .bluetoothHighQualityRecording]
                    } else {
                        bluetoothOption = .allowBluetoothHFP
                    }
                    #endif
                }
                if chatPhone {
                    try session.setCategory(.playback, options: [.mixWithOthers])
                } else {
                    try session.setCategory(
                        .playAndRecord,
                        options: [.mixWithOthers, bluetoothOption, .defaultToSpeaker]
                    )
                }
                try session.setPreferredSampleRate(48000)
                try session.setPrefersNoInterruptionsFromSystemAlerts(true)
                try session.setActive(true)
                logger.info("audio: Preferred sample rate: \(session.preferredSampleRate)")
            } catch {
                DispatchQueue.main.async {
                    self.makeErrorToast(title: "Audio session setup failed",
                                        subTitle: error.localizedDescription)
                }
            }
            DispatchQueue.main.async {
                self.setAllowHapticsAndSystemSoundsDuringRecording()
            }
        }
    }

    func teardownAudioSession() {
        processorControlQueue.async {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                logger.info("Failed to stop audio session with error: \(error)")
            }
        }
    }

    func switchMicIfNeededAfterSceneSwitch() {
        updateMics()
        if database.mics.autoSwitch {
            if let scene = getSelectedScene(), scene.overrideMic,
               let mic = getConnectedMicById(id: scene.micId)
            {
                selectMic(mic: mic)
            } else {
                if defaultMic.connected {
                    selectMic(mic: defaultMic)
                } else if let mic = getHighestPriorityConnectedMic() {
                    selectMic(mic: mic)
                }
            }
        }
    }

    func switchMicIfNeededAfterNetworkCameraChange() {
        if database.mics.autoSwitch {
            updateMics()
            if let scene = getSelectedScene(), scene.overrideMic,
               let mic = getConnectedMicById(id: scene.micId)
            {
                selectMic(mic: mic)
                if let highestPrioMic = getHighestPriorityConnectedMic() {
                    defaultMic = highestPrioMic
                }
            } else if let highestPrioMic = getHighestPriorityConnectedMic() {
                selectMic(mic: highestPrioMic)
                defaultMic = highestPrioMic
            }
        }
    }

    func markMicAsConnected(id: String) {
        getMicById(id: id)?.connected = true
    }

    func markMicAsDisconnected(id: String) {
        getMicById(id: id)?.connected = false
    }

    func updateMics() {
        updateMics(audioSession: listAudioSessionMics())
    }

    private func updateMics(audioSession: [SettingsMicsMic]) {
        updateMediaPlayerMics()
        updateRistMics()
        updateSrtlaMics()
        updateSrtClientMics()
        updateRtmpMics()
        updateWhipMics()
        updateWhepMics()
        syncMics(found: audioSession, isKind: { $0.isAudioSession() }, removeMissing: false)
    }

    func updateRtmpMics() {
        syncMics(found: listRtmpMics(), isKind: { $0.isRtmp() }, removeMissing: true)
    }

    func updateSrtlaMics() {
        syncMics(found: listSrtlaMics(), isKind: { $0.isSrtla() }, removeMissing: true)
    }

    func updateSrtClientMics() {
        syncMics(found: listSrtClientMics(), isKind: { $0.isSrtClient() }, removeMissing: true)
    }

    func updateRistMics() {
        syncMics(found: listRistMics(), isKind: { $0.isRist() }, removeMissing: true)
    }

    func updateWhipMics() {
        syncMics(found: listWhipMics(), isKind: { $0.isWhip() }, removeMissing: true)
    }

    func updateWhepMics() {
        syncMics(found: listWhepMics(), isKind: { $0.isWhep() }, removeMissing: true)
    }

    func updateMediaPlayerMics() {
        syncMics(found: listMediaPlayerMics(), isKind: { $0.isMediaPlayer() }, removeMissing: true)
    }

    func updateAudioSessionMicsAsync(onCompleted: (@MainActor () -> Void)? = nil) {
        processorControlQueue.async {
            let audioSessionMics = listAudioSessionMics()
            DispatchQueue.main.async {
                self.syncMics(found: audioSessionMics, isKind: { $0.isAudioSession() }, removeMissing: false)
                onCompleted?()
            }
        }
    }

    private func syncMics(found: [SettingsMicsMic],
                          isKind: (SettingsMicsMic) -> Bool,
                          removeMissing: Bool)
    {
        var mics = database.mics.mics
        if removeMissing {
            mics.removeAll { isKind($0) && !found.contains($0) }
        }
        for mic in mics where isKind(mic) {
            if let foundMic = found.first(where: { $0 == mic }) {
                mic.name = foundMic.name
                mic.connected = foundMic.connected
            } else {
                mic.connected = false
            }
        }
        for mic in found where !mics.contains(mic) {
            mics.insert(mic, at: 0)
        }
        database.mics.mics = mics
    }

    func getMicById(id: String) -> SettingsMicsMic? {
        database.mics.mics.first(where: { $0.id == id })
    }

    func manualSelectMicById(id: String) {
        if let mic = getAvailableMicById(id: id) {
            selectMic(mic: mic)
            defaultMic = mic
        }
    }

    func updateMicDelay() {
        media.setAudioDelay(delay: getMicById(id: mic.current.id)?.delay ?? 0)
    }

    func selectMicDefault(mic: SettingsMicsMic) {
        media.attachBufferedAudio(cameraId: nil)
        let preferStereoMic = database.audio.preferStereoMic
        processorControlQueue.async {
            let session = AVAudioSession.sharedInstance()
            guard let inputPort = session.availableInputs?.first(where: { $0.uid == mic.inputUid }) else {
                return
            }
            try? session.setPreferredInput(inputPort)
            guard let dataSourceId = mic.dataSourceId as? NSNumber,
                  let dataSource = inputPort.dataSources?.first(where: { $0.dataSourceID == dataSourceId })
            else {
                return
            }
            try? setBuiltInMicAudioMode(dataSource: dataSource, preferStereoMic: preferStereoMic)
            try? session.setInputDataSource(dataSource)
        }
        media.attachDefaultAudioDevice(builtinDelay: database.debug.builtinAudioAndVideoDelay)
        remoteControlStateChanged(state: RemoteControlAssistantStreamerState(mic: mic.id))
    }

    func keepSpeakerAlive(now: ContinuousClock.Instant) {
        KeepSpeakerAlivePlayer.shared.playIfNeeded(now: now)
    }

    func updateAudioLevel() {
        let newAudioLevel = media.getAudioLevel()
        let newNumberOfAudioChannels = media.getNumberOfAudioChannels()
        let newSampleRate = media.getAudioSampleRate()
        if newNumberOfAudioChannels != audio.numberOfChannels {
            audio.numberOfChannels = newNumberOfAudioChannels
        }
        if newSampleRate != audio.sampleRate {
            audio.sampleRate = newSampleRate
        }
        if newAudioLevel == audio.level.level {
            return
        }
        if abs(audio.level.level - newAudioLevel) > 7 {
            audio.level.level = newAudioLevel
            if isWatchLocal() {
                sendAudioLevelToWatch(audioLevel: audio.level.level)
            }
        }
    }

    func setTalkbackMic(id: String) {
        database.talkback.micId = id
        updateTalkback()
    }

    func updateTalkback() {
        if database.talkback.enabled, let mic = getMicById(id: database.talkback.micId) {
            startTalkback(mic: mic)
        } else {
            stopTalkback()
        }
    }

    @objc nonisolated func handleSystemVolumeDidChange(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let volume = userInfo["Volume"] as? Float,
              let reason = userInfo["Reason"] as? String,
              let sequenceNumber = userInfo["SequenceNumber"] as? Int
        else {
            return
        }
        DispatchQueue.main.async {
            self.handleSystemVolumeDidChange(volume: volume, reason: reason, sequenceNumber: sequenceNumber)
        }
    }

    @objc nonisolated func handleAudioRouteChange(notification _: Notification) {
        DispatchQueue.main.async {
            self.handleAudioRouteChange()
        }
    }

    private func handleAudioRouteChange() {
        updateIsBluetoothAudioOutput()
        stopTextToSpeechIfOutputNotAllowed()
        // Not sure about this...
        if isMac() {
            updateAudioSessionMicsAsync()
            return
        }
        switchMicIfNeededAfterRouteChange()
        let session = AVAudioSession.sharedInstance()
        mic.inputGainSettable = session.isInputGainSettable
        mic.inputGain = session.inputGain
    }

    func updateIsBluetoothAudioOutput() {
        isBluetoothAudioOutput = AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType)
        }
    }

    private func handleSystemVolumeDidChange(volume: Float, reason: String, sequenceNumber: Int) {
        // For some reason two similar notifications are received. Not sure how to distinguish
        // them from each other.
        guard sequenceNumber != latestVolumeChangeSequenceNumber else {
            return
        }
        latestVolumeChangeSequenceNumber = sequenceNumber
        if reason == "ExplicitVolumeChange", database.selfieStick.enabled, isAppActive {
            if initialVolume == nil {
                initialVolume = volume
            }
            guard let initialVolume else {
                return
            }
            if volume != initialVolume {
                setSystemVolume(initialVolume)
                executeSelfieStickAction()
            } else if isVolumeMinOrMax(volume), latestSetVolumeTime.duration(to: .now) > .seconds(1) {
                executeSelfieStickAction()
            }
        } else {
            initialVolume = volume
        }
    }

    private func executeSelfieStickAction() {
        handleControllerFunction(buttonId: "s:button",
                                 function: database.selfieStick.function,
                                 functionData: database.selfieStick.functionData,
                                 pressed: false)
    }

    private func isVolumeMinOrMax(_ volume: Float) -> Bool {
        volume == 0 || volume == 1
    }

    private func setSystemVolume(_ volume: Float) {
        if let volumeSlider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            // Can remove delay?
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.latestSetVolumeTime = .now
                volumeSlider.value = volume
            }
        }
    }

    private func switchMicIfNeededAfterRouteChange() {
        updateAudioSessionMicsAsync {
            if self.database.mics.autoSwitch {
                self.autoSwitchMicIfNeededAfterRouteChange()
            } else {
                self.manualSwitchMicIfNeededAfterRouteChange()
            }
        }
    }

    private func getActiveAudioSessionMic() -> SettingsMicsMic? {
        guard let inputPort = AVAudioSession.sharedInstance().currentRoute.inputs.first else {
            return nil
        }
        return makeAudioSessionMic(inputPort: inputPort, dataSource: inputPort.preferredDataSource)
    }

    private func autoSwitchMicIfNeededAfterRouteChange() {
        if let scene = getSelectedScene(), scene.overrideMic {
            if mic.current.isAudioSession() {
                if let activeMic = getActiveAudioSessionMic(), activeMic != mic.current {
                    if getMicPriority(mic: activeMic) > getMicPriority(mic: defaultMic) {
                        defaultMic = activeMic
                    }
                    selectMicDefault(mic: mic.current)
                }
            } else {
                if let activeMic = getActiveAudioSessionMic(),
                   getMicPriority(mic: activeMic) > getMicPriority(mic: defaultMic)
                {
                    defaultMic = activeMic
                }
            }
        } else {
            if let activeMic = getActiveAudioSessionMic(),
               getMicPriority(mic: activeMic) > getMicPriority(mic: mic.current)
            {
                selectMic(mic: activeMic)
                defaultMic = activeMic
            } else if getActiveAudioSessionMic() == mic.current {
            } else if mic.current.connected, mic.current.isAudioSession() {
                selectMicDefault(mic: mic.current)
            } else if let highestPrioMic = getHighestPriorityConnectedMic() {
                selectMic(mic: highestPrioMic)
                defaultMic = highestPrioMic
            }
        }
    }

    private func manualSwitchMicIfNeededAfterRouteChange() {
        if mic.current.isAudioSession(),
           getActiveAudioSessionMic() != mic.current
        {
            selectMicDefault(mic: mic.current)
        }
    }

    private func getMicPriority(mic: SettingsMicsMic) -> Int {
        if let priority = database.mics.mics.firstIndex(where: { $0.id == mic.id }) {
            -priority
        } else {
            Int.min
        }
    }

    private func getHighestPriorityConnectedMic() -> SettingsMicsMic? {
        database.mics.mics.first(where: { $0.connected })
    }

    private func makeMicChangeToast(name: String) {
        makeToast(title: String(localized: "Switched mic to '\(name)'"))
    }

    private func listRtmpMics() -> [SettingsMicsMic] {
        database.rtmpServer.streams.map {
            SettingsMicsMic(name: $0.camera(),
                            inputUid: $0.id.uuidString,
                            connected: activeBufferedVideoIds.contains($0.id))
        }
    }

    private func listSrtlaMics() -> [SettingsMicsMic] {
        database.srtlaServer.streams.map {
            SettingsMicsMic(name: $0.camera(),
                            inputUid: $0.id.uuidString,
                            connected: activeBufferedVideoIds.contains($0.id))
        }
    }

    private func listSrtClientMics() -> [SettingsMicsMic] {
        database.srtClient.streams.map {
            SettingsMicsMic(name: $0.camera(),
                            inputUid: $0.id.uuidString,
                            connected: activeBufferedVideoIds.contains($0.id))
        }
    }

    private func listRistMics() -> [SettingsMicsMic] {
        database.ristServer.streams.map {
            SettingsMicsMic(name: $0.camera(),
                            inputUid: $0.id.uuidString,
                            connected: activeBufferedVideoIds.contains($0.id))
        }
    }

    private func listWhipMics() -> [SettingsMicsMic] {
        database.whipServer.streams.map {
            SettingsMicsMic(name: $0.camera(),
                            inputUid: $0.id.uuidString,
                            connected: activeBufferedVideoIds.contains($0.id))
        }
    }

    private func listWhepMics() -> [SettingsMicsMic] {
        database.whepClient.streams.map {
            SettingsMicsMic(name: $0.camera(),
                            inputUid: $0.id.uuidString,
                            connected: activeBufferedVideoIds.contains($0.id))
        }
    }

    private func listMediaPlayerMics() -> [SettingsMicsMic] {
        database.mediaPlayers.players.map {
            SettingsMicsMic(name: $0.camera(), inputUid: $0.id.uuidString, connected: true)
        }
    }

    private func getConnectedMicById(id: String) -> SettingsMicsMic? {
        guard let mic = getMicById(id: id), mic.connected else {
            return nil
        }
        return mic
    }

    private func getAvailableMicById(id: String) -> SettingsMicsMic? {
        guard let mic = getMicById(id: id) else {
            logger.info("Mic with id \(id) not found")
            makeErrorToast(
                title: String(localized: "Mic not found"),
                subTitle: String(localized: "Mic id \(id)")
            )
            return nil
        }
        return mic
    }

    private func selectMic(mic: SettingsMicsMic) {
        guard !isChatPhone() else {
            return
        }
        self.mic.requested = mic
        trySwitchMic()
    }

    private func trySwitchMic() {
        guard !mic.isSwitchTimerRunning else {
            return
        }
        guard let mic = mic.requested else {
            return
        }
        self.mic.requested = nil
        guard mic != self.mic.current else {
            return
        }
        if self.mic.current != noMic {
            makeMicChangeToast(name: mic.name)
        }
        if isRtmpMic(mic: mic) {
            attachBufferedAudio(cameraId: getRtmpMicCameraId(mic: mic), micId: mic.id)
        } else if isSrtlaMic(mic: mic) {
            attachBufferedAudio(cameraId: getSrtlaMicCameraId(mic: mic), micId: mic.id)
        } else if isSrtClientMic(mic: mic) {
            attachBufferedAudio(cameraId: getSrtClientCameraId(mic: mic), micId: mic.id)
        } else if isRistMic(mic: mic) {
            attachBufferedAudio(cameraId: getRistMicCameraId(mic: mic), micId: mic.id)
        } else if isWhipMic(mic: mic) {
            attachBufferedAudio(cameraId: getWhipMicCameraId(mic: mic), micId: mic.id)
        } else if isWhepMic(mic: mic) {
            attachBufferedAudio(cameraId: getWhepMicCameraId(mic: mic), micId: mic.id)
        } else if isMediaPlayerMic(mic: mic) {
            attachBufferedAudio(cameraId: getMediaPlayerMicCameraId(mic: mic), micId: mic.id)
        } else {
            selectMicDefault(mic: mic)
        }
        self.mic.current = mic
        updateMicDelay()
        self.mic.isSwitchTimerRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.mic.isSwitchTimerRunning = false
            self.trySwitchMic()
        }
    }

    private func isRtmpMic(mic: SettingsMicsMic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getRtmpStream(id: id) != nil
    }

    private func isSrtlaMic(mic: SettingsMicsMic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getSrtlaStream(id: id) != nil
    }

    private func isSrtClientMic(mic: SettingsMicsMic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getSrtClientStream(id: id) != nil
    }

    private func isRistMic(mic: SettingsMicsMic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getRistStream(id: id) != nil
    }

    private func isWhipMic(mic: SettingsMicsMic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getWhipStream(id: id) != nil
    }

    private func isWhepMic(mic: SettingsMicsMic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getWhepStream(id: id) != nil
    }

    private func isMediaPlayerMic(mic: SettingsMicsMic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getMediaPlayer(id: id) != nil
    }

    private func getRtmpMicCameraId(mic: SettingsMicsMic) -> UUID? {
        getRtmpStream(idString: mic.inputUid)?.id
    }

    private func getSrtlaMicCameraId(mic: SettingsMicsMic) -> UUID? {
        getSrtlaStream(idString: mic.inputUid)?.id
    }

    private func getSrtClientCameraId(mic: SettingsMicsMic) -> UUID? {
        getSrtClientStream(idString: mic.inputUid)?.id
    }

    private func getRistMicCameraId(mic: SettingsMicsMic) -> UUID? {
        getRistStream(idString: mic.inputUid)?.id
    }

    private func getWhipMicCameraId(mic: SettingsMicsMic) -> UUID? {
        getWhipStream(idString: mic.inputUid)?.id
    }

    private func getWhepMicCameraId(mic: SettingsMicsMic) -> UUID? {
        getWhepStream(idString: mic.inputUid)?.id
    }

    private func getMediaPlayerMicCameraId(mic: SettingsMicsMic) -> UUID? {
        getMediaPlayer(idString: mic.inputUid)?.id
    }

    private func attachBufferedAudio(cameraId: UUID?, micId: String) {
        guard let cameraId else {
            logger.info("Cannot attach unknown mic \(micId)")
            return
        }
        media.attachBufferedAudio(cameraId: cameraId)
        remoteControlStateChanged(state: RemoteControlAssistantStreamerState(mic: micId))
    }

    private func startTalkback(mic: SettingsMicsMic) {
        if isRtmpMic(mic: mic) {
            media.setTalkback(cameraId: getRtmpMicCameraId(mic: mic))
        } else if isSrtlaMic(mic: mic) {
            media.setTalkback(cameraId: getSrtlaMicCameraId(mic: mic))
        } else if isSrtClientMic(mic: mic) {
            media.setTalkback(cameraId: getSrtClientCameraId(mic: mic))
        } else if isRistMic(mic: mic) {
            media.setTalkback(cameraId: getRistMicCameraId(mic: mic))
        } else if isWhipMic(mic: mic) {
            media.setTalkback(cameraId: getWhipMicCameraId(mic: mic))
        } else if isWhepMic(mic: mic) {
            media.setTalkback(cameraId: getWhepMicCameraId(mic: mic))
        } else if isMediaPlayerMic(mic: mic) {
            media.setTalkback(cameraId: getMediaPlayerMicCameraId(mic: mic))
        } else {
            media.setTalkback(cameraId: nil)
        }
    }

    private func stopTalkback() {
        media.setTalkback(cameraId: nil)
    }
}

private func setBuiltInMicAudioMode(
    dataSource: AVAudioSessionDataSourceDescription,
    preferStereoMic: Bool
) throws {
    if preferStereoMic {
        if dataSource.supportedPolarPatterns?.contains(.stereo) == true {
            try dataSource.setPreferredPolarPattern(.stereo)
        } else {
            try dataSource.setPreferredPolarPattern(.none)
        }
    } else {
        try dataSource.setPreferredPolarPattern(.none)
    }
}

private func listAudioSessionMics() -> [SettingsMicsMic] {
    var mics: [SettingsMicsMic] = []
    for inputPort in AVAudioSession.sharedInstance().availableInputs ?? [] {
        if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
            var builtInMics: [SettingsMicsMic] = []
            for dataSource in dataSources {
                let mic = makeAudioSessionMic(inputPort: inputPort, dataSource: dataSource)
                switch mic.builtInOrientation {
                case .bottom, .top:
                    builtInMics.append(mic)
                default:
                    builtInMics.insert(mic, at: 0)
                }
            }
            mics += builtInMics
        } else {
            mics.append(makeAudioSessionMic(inputPort: inputPort, dataSource: nil))
        }
    }
    return mics
}

private func makeAudioSessionMic(inputPort: AVAudioSessionPortDescription,
                                 dataSource: AVAudioSessionDataSourceDescription?) -> SettingsMicsMic
{
    let mic = SettingsMicsMic()
    mic.inputUid = inputPort.uid
    mic.connected = true
    if let dataSource {
        if inputPort.portType == .builtInMic {
            mic.name = dataSource.dataSourceName
            mic.builtInOrientation = getBuiltInMicOrientation(orientation: dataSource.orientation)
        } else {
            mic.name = "\(inputPort.portName): \(dataSource.dataSourceName)"
        }
        mic.dataSourceId = dataSource.dataSourceID.intValue
    } else {
        mic.name = inputPort.portName
    }
    return mic
}

private func getBuiltInMicOrientation(orientation: AVAudioSession.Orientation?) -> SettingsMic? {
    guard let orientation else {
        return nil
    }
    switch orientation {
    case .bottom:
        return .bottom
    case .front:
        return .front
    case .back:
        return .back
    case .top:
        return .top
    default:
        return nil
    }
}
