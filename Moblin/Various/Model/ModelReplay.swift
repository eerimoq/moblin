import SwiftUI

class ReplayProvider: ObservableObject {
    @Published var selectedId: UUID?
    @Published var isSaving = false
    @Published var previewImage: UIImage?
    @Published var isPlaying = false
    @Published var startFromEnd = 10.0
    @Published var speed: SettingsReplaySpeed? = .one
    @Published var instantReplayCountdown = 0
    @Published var timeLeft = 0
}

extension Model {
    func saveReplay(start: Double? = nil,
                    delay: Int? = nil,
                    completion: ((ReplaySettings) -> Void)? = nil) -> Bool
    {
        guard !replay.isSaving else {
            return false
        }
        replay.isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay ?? 5)) {
            self.replayBuffer.createFile { file in
                DispatchQueue.main.async {
                    self.replay.isSaving = false
                    guard let file else {
                        return
                    }
                    let replaySettings = self.replaysStorage.createReplay()
                    replaySettings.start = start ?? self.database.replay.start
                    replaySettings.stop = self.database.replay.stop
                    replaySettings.duration = file.duration
                    try? FileManager.default.copyItem(at: file.url, to: replaySettings.url())
                    self.replaysStorage.append(replay: replaySettings)
                    completion?(replaySettings)
                }
            }
        }
        return true
    }

    func loadReplay(video: ReplaySettings, completion: (() -> Void)? = nil) {
        replaySettings = video
        replay.startFromEnd = video.startFromEnd()
        replay.selectedId = video.id
        replayFrameExtractor = ReplayFrameExtractor(
            video: ReplayBufferFile(url: video.url(), duration: video.duration, remove: false),
            offset: video.thumbnailOffset(),
            delegate: self,
            completion: completion
        )
    }

    func replaySpeedChanged() {
        database.replay.speed = replay.speed ?? .one
    }

    func instantReplay(start: Double? = nil, delay: Int? = nil) {
        guard replay.instantReplayCountdown == 0 else {
            return
        }
        let savingStarted = saveReplay(start: start, delay: delay) { video in
            self.loadReplay(video: video) {
                self.replay.isPlaying = true
                if !self.replayPlay() {
                    self.replay.isPlaying = false
                }
            }
        }
        if savingStarted {
            replay.instantReplayCountdown = delay ?? 6
            instantReplayCountdownTick()
        }
    }

    private func instantReplayCountdownTick() {
        guard replay.instantReplayCountdown != 0 else {
            return
        }
        replay.instantReplayCountdown -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.instantReplayCountdownTick()
        }
    }

    func makeReplayIsNotEnabledToast() {
        makeToast(
            title: String(localized: "Replay is not enabled"),
            subTitle: String(localized: "Tap here to enable it.")
        ) {
            self.stream.replay.enabled = true
            self.streamReplayEnabledUpdated()
            self.makeToast(title: String(localized: "Replay enabled"))
        }
    }

    func setReplayPosition(start: Double) {
        guard let replaySettings else {
            return
        }
        replaySettings.start = start
        replaySettings.stop = SettingsReplay.stop
        database.replay.start = start
        replayFrameExtractor?.seek(offset: replaySettings.thumbnailOffset())
    }

    func replayPlay() -> Bool {
        replayCancel()
        guard let replayVideo, let replaySettings else {
            return false
        }
        let replay = stream.replay
        let transitionMode: ReplayEffectTransitionMode
        switch replay.transitionType {
        case .none:
            transitionMode = .none
        case .fade:
            transitionMode = .fade
        case .stingers:
            let inPath = replayTransitionsStorage.makePath(filename: replay.inStinger.makeFilename() ?? "")
            let outPath = replayTransitionsStorage.makePath(filename: replay.outStinger.makeFilename() ?? "")
            transitionMode = .stingers(inPath: inPath,
                                       inTransitionPoint: replay.inStinger.transitionPoint,
                                       outPath: outPath,
                                       outTransitionPoint: replay.outStinger.transitionPoint)
        }
        replayEffect = ReplayEffect(
            video: replayVideo,
            start: replaySettings.startFromVideoStart(),
            stop: replaySettings.stopFromVideoStart(),
            speed: database.replay.speed.toNumber(),
            size: stream.dimensions(),
            transitionMode: transitionMode,
            delegate: self
        )
        media.registerEffectBack(replayEffect!)
        return true
    }

    func replayCancel() {
        replayEffect?.cancel()
        replayEffect = nil
    }

    func streamReplayEnabledUpdated() {
        replayBuffer = ReplayBuffer()
        media.setReplayBuffering(enabled: stream.replay.enabled)
        if stream.replay.enabled {
            startRecorderIfNeeded()
        } else {
            stopRecorderIfNeeded()
        }
    }

    func handleRecorderInitSegment(data: Data) {
        replayBuffer.setInitSegment(data: data)
    }

    func handleRecorderDataSegment(segment: RecorderDataSegment) {
        replayBuffer.appendDataSegment(segment: segment)
    }
}

extension Model: ReplayDelegate {
    func replayOutputFrame(image: UIImage, offset _: Double, video: ReplayBufferFile, completion: (() -> Void)?) {
        DispatchQueue.main.async {
            self.replay.previewImage = image
            self.replayVideo = video
            completion?()
        }
    }
}

extension Model: ReplayEffectDelegate {
    func replayEffectStatus(timeLeft: Int) {
        DispatchQueue.main.async {
            self.replay.timeLeft = timeLeft
        }
    }

    func replayEffectCompleted() {
        DispatchQueue.main.async {
            self.replay.isPlaying = false
        }
    }

    func replayEffectError(message: String) {
        makeErrorToastMain(title: message)
    }
}
