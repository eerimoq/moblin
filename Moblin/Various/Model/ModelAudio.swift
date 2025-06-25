import AVFAudio
import UIKit

class AudioProvider: ObservableObject {
    @Published var showing = false
    @Published var level: Float = defaultAudioLevel
    @Published var numberOfChannels: Int = 0
}

extension Model {
    func reloadAudioSession() {
        teardownAudioSession()
        setupAudioSession()
        media.attachDefaultAudioDevice(builtinDelay: database.debug.builtinAudioAndVideoDelay)
    }

    func setupAudioSession() {
        let bluetoothOutputOnly = database.debug.bluetoothOutputOnly
        netStreamLockQueue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                let bluetoothOption: AVAudioSession.CategoryOptions
                if bluetoothOutputOnly {
                    bluetoothOption = .allowBluetoothA2DP
                } else {
                    bluetoothOption = .allowBluetooth
                }
                try session.setCategory(
                    .playAndRecord,
                    options: [.mixWithOthers, bluetoothOption, .defaultToSpeaker]
                )
                try session.setActive(true)
            } catch {
                logger.error("app: Session error \(error)")
            }
            self.setAllowHapticsAndSystemSoundsDuringRecording()
        }
    }

    func teardownAudioSession() {
        netStreamLockQueue.async {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                logger.info("Failed to stop audio session with error: \(error)")
            }
        }
    }

    @objc func systemVolumeDidChange(notification: NSNotification) {
        DispatchQueue.main.async {
            self.handleSystemVolumeDidChange(notification: notification)
        }
    }

    private func handleSystemVolumeDidChange(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let volume = userInfo["Volume"] as? Float,
              let reason = userInfo["Reason"] as? String,
              let sequenceNumber = userInfo["SequenceNumber"] as? Int
        else {
            return
        }
        // For some reason two similar notifications are received. Not sure how to distinguish
        // them from each other.
        guard sequenceNumber != latestVolumeChangeSequenceNumber else {
            return
        }
        latestVolumeChangeSequenceNumber = sequenceNumber
        if reason == "ExplicitVolumeChange", database.selfieStick.buttonEnabled, isAppActive {
            if initialVolume == nil {
                initialVolume = volume
            }
            guard let initialVolume else {
                return
            }
            if volume != initialVolume {
                setSystemVolume(initialVolume)
                switchToNextSceneRoundRobin()
            } else if isVolumeMinOrMax(volume), latestSetVolumeTime.duration(to: .now) > .seconds(1) {
                switchToNextSceneRoundRobin()
            }
        } else {
            initialVolume = volume
        }
    }

    private func isVolumeMinOrMax(_ volume: Float) -> Bool {
        return volume == 0 || volume == 1
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

    @objc func handleAudioRouteChange(notification _: Notification) {
        guard let inputPort = AVAudioSession.sharedInstance().currentRoute.inputs.first
        else {
            return
        }
        updateMicsList()
        var newMic: Mic
        if let dataSource = inputPort.preferredDataSource {
            var name: String
            var builtInMicOrientation: SettingsMic?
            if inputPort.portType == .builtInMic {
                name = dataSource.dataSourceName
                builtInMicOrientation = getBuiltInMicOrientation(orientation: dataSource.orientation)
            } else {
                name = "\(inputPort.portName): \(dataSource.dataSourceName)"
            }
            newMic = Mic(
                name: name,
                inputUid: inputPort.uid,
                dataSourceID: dataSource.dataSourceID,
                builtInOrientation: builtInMicOrientation
            )
        } else if inputPort.portType != .builtInMic {
            newMic = Mic(name: inputPort.portName, inputUid: inputPort.uid)
        } else {
            return
        }
        if newMic == micChange {
            return
        }
        if micChange != noMic {
            makeToast(title: newMic.name)
        }
        if newMic != currentMic {
            selectMicDefault(mic: newMic)
        }
        micChange = newMic
    }

    func updateMicsList() {
        mics = listMics()
        for mic in mics {
            let micsMic = SettingsMicsMic()
            micsMic.name = mic.name
            micsMic.inputUid = mic.inputUid
            micsMic.dataSourceID = mic.dataSourceID?.intValue
            if !database.mics.mics.contains(where: { $0 == micsMic }) {
                database.mics.mics.append(micsMic)
            }
        }
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

    func listMics() -> [Mic] {
        var mics: [Mic] = []
        listAudioSessionMics(&mics)
        listRtmpMics(&mics)
        listSrtlaMics(&mics)
        listMediaPlayerMics(&mics)
        return mics
    }

    private func listAudioSessionMics(_ mics: inout [Mic]) {
        for inputPort in AVAudioSession.sharedInstance().availableInputs ?? [] {
            if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
                addAudioSessionBuiltinMics(&mics, inputPort, dataSources)
            } else {
                addAudioSessionExternalMics(&mics, inputPort)
            }
        }
    }

    private func addAudioSessionBuiltinMics(_ mics: inout [Mic],
                                            _ inputPort: AVAudioSessionPortDescription,
                                            _ dataSources: [AVAudioSessionDataSourceDescription])
    {
        for dataSource in dataSources {
            var name: String
            var builtInOrientation: SettingsMic?
            if inputPort.portType == .builtInMic {
                name = dataSource.dataSourceName
                builtInOrientation = getBuiltInMicOrientation(orientation: dataSource.orientation)
            } else {
                name = "\(inputPort.portName): \(dataSource.dataSourceName)"
            }
            mics.append(Mic(
                name: name,
                inputUid: inputPort.uid,
                dataSourceID: dataSource.dataSourceID,
                builtInOrientation: builtInOrientation
            ))
        }
    }

    private func addAudioSessionExternalMics(_ mics: inout [Mic], _ inputPort: AVAudioSessionPortDescription) {
        mics.append(Mic(name: inputPort.portName, inputUid: inputPort.uid))
    }

    private func listRtmpMics(_ mics: inout [Mic]) {
        for rtmpCamera in rtmpCameras() {
            guard let stream = getRtmpStream(camera: rtmpCamera) else {
                continue
            }
            if isRtmpStreamConnected(streamKey: stream.streamKey) {
                mics.append(Mic(
                    name: rtmpCamera,
                    inputUid: stream.id.uuidString,
                    builtInOrientation: nil
                ))
            }
        }
    }

    private func listSrtlaMics(_ mics: inout [Mic]) {
        for srtlaCamera in srtlaCameras() {
            guard let stream = getSrtlaStream(camera: srtlaCamera) else {
                continue
            }
            if isSrtlaStreamConnected(streamId: stream.streamId) {
                mics.append(Mic(
                    name: srtlaCamera,
                    inputUid: stream.id.uuidString,
                    builtInOrientation: nil
                ))
            }
        }
    }

    private func listMediaPlayerMics(_ mics: inout [Mic]) {
        for mediaPlayerCamera in mediaPlayerCameras() {
            guard let mediaPlayer = getMediaPlayer(camera: mediaPlayerCamera) else {
                continue
            }
            mics.append(Mic(
                name: mediaPlayerCamera,
                inputUid: mediaPlayer.id.uuidString,
                builtInOrientation: nil
            ))
        }
    }

    func setMic() {
        let wantedOrientation: AVAudioSession.Orientation
        switch database.mic {
        case .bottom:
            wantedOrientation = .bottom
        case .front:
            wantedOrientation = .front
        case .back:
            wantedOrientation = .back
        case .top:
            wantedOrientation = .top
        }
        let preferStereoMic = database.debug.preferStereoMic
        netStreamLockQueue.async {
            let session = AVAudioSession.sharedInstance()
            for inputPort in session.availableInputs ?? [] {
                if inputPort.portType != .builtInMic {
                    continue
                }
                if let dataSources = inputPort.dataSources, !dataSources.isEmpty {
                    for dataSource in dataSources where dataSource.orientation == wantedOrientation {
                        try? self.setBuiltInMicAudioMode(dataSource: dataSource, preferStereoMic: preferStereoMic)
                        try? inputPort.setPreferredDataSource(dataSource)
                    }
                }
            }
        }
        media.attachDefaultAudioDevice(builtinDelay: database.debug.builtinAudioAndVideoDelay)
    }

    func setMicFromSettings() {
        if let mic = mics.first(where: { mic in mic.builtInOrientation == database.mic }) {
            selectMic(mic: mic)
        } else if let mic = mics.first {
            selectMic(mic: mic)
        } else {
            logger.error("No mic to select from settings.")
        }
    }

    func selectMicById(id: String) {
        guard let mic = mics.first(where: { mic in mic.id == id }) else {
            logger.info("Mic with id \(id) not found")
            makeErrorToast(
                title: String(localized: "Mic not found"),
                subTitle: String(localized: "Mic id \(id)")
            )
            return
        }
        selectMic(mic: mic)
    }

    private func selectMic(mic: Mic) {
        if isRtmpMic(mic: mic) {
            selectMicRtmp(mic: mic)
        } else if isSrtlaMic(mic: mic) {
            selectMicSrtla(mic: mic)
        } else if isMediaPlayerMic(mic: mic) {
            selectMicMediaPlayer(mic: mic)
        } else {
            selectMicDefault(mic: mic)
        }
    }

    private func isRtmpMic(mic: Mic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getRtmpStream(id: id) != nil
    }

    private func isSrtlaMic(mic: Mic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getSrtlaStream(id: id) != nil
    }

    private func isMediaPlayerMic(mic: Mic) -> Bool {
        guard let id = UUID(uuidString: mic.inputUid) else {
            return false
        }
        return getMediaPlayer(id: id) != nil
    }

    private func selectMicRtmp(mic: Mic) {
        currentMic = mic
        let cameraId = getRtmpStream(camera: mic.name)?.id ?? .init()
        media.attachBufferedAudio(cameraId: cameraId)
        remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
    }

    private func selectMicSrtla(mic: Mic) {
        currentMic = mic
        let cameraId = getSrtlaStream(camera: mic.name)?.id ?? .init()
        media.attachBufferedAudio(cameraId: cameraId)
        remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
    }

    private func selectMicMediaPlayer(mic: Mic) {
        currentMic = mic
        let cameraId = getMediaPlayer(camera: mic.name)?.id ?? .init()
        media.attachBufferedAudio(cameraId: cameraId)
        remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
    }

    private func selectMicDefault(mic: Mic) {
        media.attachBufferedAudio(cameraId: nil)
        let preferStereoMic = database.debug.preferStereoMic
        netStreamLockQueue.async {
            let session = AVAudioSession.sharedInstance()
            for inputPort in session.availableInputs ?? [] {
                if mic.inputUid != inputPort.uid {
                    continue
                }
                try? session.setPreferredInput(inputPort)
                if let dataSourceID = mic.dataSourceID {
                    for dataSource in inputPort.dataSources ?? [] {
                        if dataSourceID != dataSource.dataSourceID {
                            continue
                        }
                        try? self.setBuiltInMicAudioMode(dataSource: dataSource, preferStereoMic: preferStereoMic)
                        try? session.setInputDataSource(dataSource)
                    }
                }
            }
        }
        media.attachDefaultAudioDevice(builtinDelay: database.debug.builtinAudioAndVideoDelay)
        currentMic = mic
        saveSelectedMic(mic: mic)
        remoteControlStreamer?.stateChanged(state: RemoteControlState(mic: mic.id))
    }

    private func saveSelectedMic(mic: Mic) {
        guard let orientation = mic.builtInOrientation, database.mic != orientation else {
            return
        }
        database.mic = orientation
    }

    private func setBuiltInMicAudioMode(dataSource: AVAudioSessionDataSourceDescription, preferStereoMic: Bool) throws {
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

    func keepSpeakerAlive(now: ContinuousClock.Instant) {
        guard keepSpeakerAliveLatestPlayed.duration(to: now) > .seconds(5 * 60) else {
            return
        }
        keepSpeakerAliveLatestPlayed = now
        guard let soundUrl = Bundle.main.url(forResource: "Alerts.bundle/Silence", withExtension: "mp3")
        else {
            return
        }
        keepSpeakerAlivePlayer = try? AVAudioPlayer(contentsOf: soundUrl)
        keepSpeakerAlivePlayer?.play()
    }

    func updateAudioLevel() {
        if database.show.audioLevel != audio.showing {
            audio.showing = database.show.audioLevel
        }
        let newAudioLevel = media.getAudioLevel()
        let newNumberOfAudioChannels = media.getNumberOfAudioChannels()
        if newNumberOfAudioChannels != audio.numberOfChannels {
            audio.numberOfChannels = newNumberOfAudioChannels
        }
        if newAudioLevel == audio.level {
            return
        }
        if abs(audio.level - newAudioLevel) > 5
            || newAudioLevel.isNaN
            || newAudioLevel == .infinity
            || audio.level.isNaN
            || audio.level == .infinity
        {
            audio.level = newAudioLevel
            if isWatchLocal() {
                sendAudioLevelToWatch(audioLevel: audio.level)
            }
        }
    }
}
