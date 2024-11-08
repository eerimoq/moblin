import AVFoundation

protocol MediaPlayerDelegate: AnyObject {
    func mediaPlayerFileLoaded(playerId: UUID, name: String)
    func mediaPlayerFileUnloaded(playerId: UUID)
    func mediaPlayerStateUpdate(playerId: UUID, name: String, playing: Bool, position: Double, time: String)
    func mediaPlayerVideoBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
    func mediaPlayerAudioBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
}

private let mediaPlayerQueue = DispatchQueue(label: "com.eerimoq.moblin.media-player")

class MediaPlayer {
    private var asset: AVAsset?
    private var reader: AVAssetReader?
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    private var audioTrackOutput: AVAssetReaderTrackOutput?
    private var settings: SettingsMediaPlayer
    private var mediaStorage: MediaPlayerStorage
    private var playing = false
    private var currentFileIndex = 0
    private var fileDuration = 0.0
    private var seeking = false
    private var startVideoTime: CMTime = .zero
    private var latestVideoTime: CMTime = .zero
    private var startAudioTime: CMTime = .zero
    private var latestAudioTime: CMTime = .zero
    private var outputTimer = SimpleTimer(queue: mediaPlayerQueue)
    private var active = false
    private var filename = ""
    var delegate: (any MediaPlayerDelegate)?

    init(settings: SettingsMediaPlayer, mediaStorage: MediaPlayerStorage) {
        self.settings = settings.clone()
        self.mediaStorage = mediaStorage
        mediaPlayerQueue.async {
            self.loadCurrentFile()
        }
    }

    deinit {
        stopOutputTimer()
    }

    func activate() {
        mediaPlayerQueue.async {
            self.activateInner()
        }
    }

    func deactivate() {
        mediaPlayerQueue.async {
            self.active = false
        }
    }

    func updateSettings(settings: SettingsMediaPlayer) {
        let settings = settings.clone()
        mediaPlayerQueue.async {
            self.updateSettingsInner(settings: settings)
        }
    }

    func updateSettingsInner(settings: SettingsMediaPlayer) {
        self.settings = settings
    }

    func play() {
        mediaPlayerQueue.async {
            self.playing = true
            let now = outputPresentationTimeStamp()
            self.startVideoTime = now - self.latestVideoTime
            self.startAudioTime = now - self.latestAudioTime
        }
    }

    func pause() {
        mediaPlayerQueue.async {
            self.playing = false
        }
    }

    func next() {
        mediaPlayerQueue.async {
            self.nextInner()
        }
    }

    func previous() {
        mediaPlayerQueue.async {
            self.previousInner()
        }
    }

    func seek(position: Double) {
        mediaPlayerQueue.async {
            self.seekInner(position: position)
        }
    }

    func setSeeking(on: Bool) {
        mediaPlayerQueue.async {
            self.seeking = on
        }
    }

    private func activateInner() {
        active = true
        reportState()
    }

    private func reportState() {
        guard active else {
            return
        }
        let time = latestVideoTime.seconds
        delegate?.mediaPlayerStateUpdate(
            playerId: settings.id,
            name: filename,
            playing: playing,
            position: 100 * time / fileDuration,
            time: formatTime(time)
        )
    }

    private func nextInner() {
        currentFileIndex += 1
        if currentFileIndex >= settings.playlist.count {
            currentFileIndex = 0
        }
        loadCurrentFile()
    }

    private func previousInner() {
        currentFileIndex -= 1
        if currentFileIndex == -1 {
            currentFileIndex = settings.playlist.count - 1
        }
        loadCurrentFile()
    }

    private func seekInner(position: Double) {
        guard let currentFile = getCurrentFile() else {
            return
        }
        delegate?.mediaPlayerStateUpdate(playerId: settings.id,
                                         name: currentFile.name,
                                         playing: playing,
                                         position: position,
                                         time: formatTime(Double(position) / 100 * fileDuration))
    }

    private func loadCurrentFile() {
        stopOutputTimer()
        latestVideoTime = .zero
        if reader != nil {
            delegate?.mediaPlayerFileUnloaded(playerId: settings.id)
            reportState()
            reader = nil
        }
        videoTrackOutput = nil
        audioTrackOutput = nil
        asset = nil
        guard let currentFile = getCurrentFile() else {
            return
        }
        filename = currentFile.name
        let url = mediaStorage.makePath(id: currentFile.id)
        asset = AVAsset(url: url)
        guard let asset else {
            logger.info("media-player: No asset \(url)")
            return
        }
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            logger.info("media-player: Failed to create reader with error: \(error)")
        }
        fileDuration = max(asset.duration.seconds, 1)
        asset.loadTracks(withMediaType: .video) { tracks, error in
            mediaPlayerQueue.async {
                self.loadVideoTrackCompletion(tracks: tracks, error: error)
            }
        }
    }

    private func loadVideoTrackCompletion(tracks: [AVAssetTrack]?, error: (any Error)?) {
        guard error == nil, let videoTrack = tracks?.first, let asset, let reader else {
            return
        }
        let videoOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [String: Any]
        videoTrackOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: videoOutputSettings
        )
        reader.add(videoTrackOutput!)
        asset.loadTracks(withMediaType: .audio) { tracks, error in
            self.loadAudioTrackCompletion(tracks: tracks, error: error)
        }
    }

    private func loadAudioTrackCompletion(tracks: [AVAssetTrack]?, error: (any Error)?) {
        guard let audioTrack = tracks?.first else {
            logger.info("media-player: No audio in file.")
            startReading()
            return
        }
        guard error == nil, let reader else {
            logger.info("media-player: Some error 2")
            return
        }
        let audioOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48000.0,
        ] as [String: Any]
        audioTrackOutput = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: audioOutputSettings
        )
        reader.add(audioTrackOutput!)
        startReading()
    }

    private func startReading() {
        guard let reader, reader.startReading() == true else {
            logger.info("media-player: Start reading failed")
            return
        }
        guard let currentFile = getCurrentFile() else {
            return
        }
        delegate?.mediaPlayerFileLoaded(playerId: settings.id, name: currentFile.name)
        reportState()
        startVideoTime = outputPresentationTimeStamp()
        startAudioTime = startVideoTime
        _ = outputVideoBuffer()
        reportState()
        startOutputTimer()
    }

    private func outputVideoBuffer() -> CMTime? {
        guard let sampleBuffer = videoTrackOutput?.copyNextSampleBuffer() else {
            return nil
        }
        latestVideoTime = sampleBuffer.presentationTimeStamp
        let presentationTimeStamp = startVideoTime + sampleBuffer.presentationTimeStamp
        guard let sampleBuffer = sampleBuffer.replacePresentationTimeStamp(presentationTimeStamp) else {
            return nil
        }
        delegate?.mediaPlayerVideoBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
        return presentationTimeStamp
    }

    private func outputAudioBuffer() -> CMTime? {
        guard let sampleBuffer = audioTrackOutput?.copyNextSampleBuffer() else {
            return nil
        }
        latestAudioTime = sampleBuffer.presentationTimeStamp
        let presentationTimeStamp = startAudioTime + sampleBuffer.presentationTimeStamp
        guard let sampleBuffer = sampleBuffer.replacePresentationTimeStamp(presentationTimeStamp) else {
            return nil
        }
        delegate?.mediaPlayerAudioBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
        return presentationTimeStamp
    }

    private func startOutputTimer() {
        outputTimer.startPeriodic(interval: 0.3, initial: 0) { [weak self] in
            self?.handleOutputTimer()
        }
    }

    private func stopOutputTimer() {
        outputTimer.stop()
    }

    private func handleOutputTimer() {
        guard playing else {
            return
        }
        let now = outputPresentationTimeStamp()
        while true {
            if let time = outputVideoBuffer() {
                if time >= now {
                    break
                }
            } else {
                nextInner()
                break
            }
        }
        if audioTrackOutput != nil {
            while true {
                if let time = outputAudioBuffer() {
                    if time >= now {
                        break
                    }
                } else {
                    nextInner()
                    break
                }
            }
        }
        reportState()
    }

    private func formatTime(_ time: Double) -> String {
        let time = Int(time.rounded())
        let seconds = String(format: "%02d", time % 60)
        let minutes = time / 60
        return "\(minutes):\(seconds)"
    }

    private func getCurrentFile() -> SettingsMediaPlayerFile? {
        guard currentFileIndex < settings.playlist.count else {
            logger.info("media-player: File index out of range")
            return nil
        }
        return settings.playlist[currentFileIndex]
    }
}

private func outputPresentationTimeStamp() -> CMTime {
    return currentPresentationTimeStamp() + CMTime(seconds: 0.5, preferredTimescale: 1000)
}
