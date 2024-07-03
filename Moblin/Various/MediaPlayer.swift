import AVFoundation

protocol MediaPlayerDelegate: AnyObject {
    func mediaPlayerOnLoad(playerId: UUID, name: String)
    func mediaPlayerOnUnload(playerId: UUID)
    func mediaPlayerOnPositionChanged(playerId: UUID, position: Double, time: String)
    func mediaPlayerOnVideoBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
    func mediaPlayerOnAudioBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
}

private let mediaPlayerQueue = DispatchQueue(label: "com.eerimoq.moblin.media-player")

class MediaPlayer {
    private var asset: AVAsset?
    private var reader: AVAssetReader?
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    // private var audioTrackOutput: AVAssetReaderTrackOutput?
    private var settings: SettingsMediaPlayer
    private var mediaStorage: MediaStorage
    private var playing = false
    private var currentFileIndex = 0
    private var fileDuration = 0.0
    private var seeking = false
    private var startTime: CMTime = .zero
    private var latestVideoTime: CMTime = .zero
    private var outputTimer: DispatchSourceTimer?
    var delegate: (any MediaPlayerDelegate)?

    init(settings: SettingsMediaPlayer, mediaStorage: MediaStorage) {
        self.settings = settings.clone()
        self.mediaStorage = mediaStorage
        mediaPlayerQueue.async {
            self.loadCurrentFile()
        }
    }

    deinit {
        stopOutputTimer()
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
            self.startTime = CMTimeSubtract(CMClockGetTime(CMClockGetHostTimeClock()), self.latestVideoTime)
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
        delegate?.mediaPlayerOnPositionChanged(
            playerId: settings.id,
            position: position,
            time: formatTime(Double(position) / 100 * fileDuration)
        )
    }

    private func loadCurrentFile() {
        stopOutputTimer()
        latestVideoTime = .zero
        if reader != nil {
            delegate?.mediaPlayerOnUnload(playerId: settings.id)
        }
        videoTrackOutput = nil
        // audioTrackOutput = nil
        reader = nil
        guard currentFileIndex < settings.playlist.count else {
            logger.info("media-player: File index out of range")
            return
        }
        let url = mediaStorage.makePath(id: settings.playlist[currentFileIndex].id)
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
        guard error == nil, let videoTrack = tracks?.first, let reader else {
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
        startReading()
        // asset.loadTracks(withMediaType: .audio) { tracks, error in
        //     self.loadAudioTrackCompletion(tracks: tracks, error: error)
        // }
    }

    // private func loadAudioTrackCompletion(tracks: [AVAssetTrack]?, error: (any Error)?) {
    //     guard error == nil, let audioTrack = tracks?.first, let reader else {
    //         logger.info("media-player: Some error 2")
    //         return
    //     }
    //     let audioOutputSettings: [String: Any] = [
    //         AVFormatIDKey: kAudioFormatLinearPCM,
    //         AVSampleRateKey: 48000.0,
    //     ] as [String: Any]
    //     audioTrackOutput = AVAssetReaderTrackOutput(
    //         track: audioTrack,
    //         outputSettings: audioOutputSettings
    //     )
    //     reader.add(audioTrackOutput!)
    // }

    private func startReading() {
        guard let reader, reader.startReading() == true else {
            logger.info("media-player: Start reading failed")
            return
        }
        guard currentFileIndex < settings.playlist.count else {
            logger.info("media-player: File index out of range")
            return
        }
        delegate?.mediaPlayerOnLoad(playerId: settings.id, name: settings.playlist[currentFileIndex].name)
        startTime = CMClockGetTime(CMClockGetHostTimeClock())
        _ = outputVideoBuffer()
        startOutputTimer()
    }

    private func outputVideoBuffer() -> CMTime? {
        guard let sampleBuffer = videoTrackOutput?.copyNextSampleBuffer() else {
            return nil
        }
        latestVideoTime = sampleBuffer.presentationTimeStamp
        let time = latestVideoTime.seconds
        let presentationTimeStamp = CMTimeAdd(startTime, sampleBuffer.presentationTimeStamp)
        guard let sampleBuffer = sampleBuffer.replacePresentationTimeStamp(presentationTimeStamp) else {
            return nil
        }
        delegate?.mediaPlayerOnVideoBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
        delegate?.mediaPlayerOnPositionChanged(
            playerId: settings.id,
            position: 100 * time / fileDuration,
            time: formatTime(time)
        )
        return presentationTimeStamp
    }

    private func startOutputTimer() {
        outputTimer = DispatchSource.makeTimerSource(queue: mediaPlayerQueue)
        outputTimer?.schedule(deadline: .now(), repeating: 0.1)
        outputTimer?.setEventHandler { [weak self] in
            self?.handleOutputTimer()
        }
        outputTimer?.activate()
    }

    private func stopOutputTimer() {
        outputTimer?.cancel()
        outputTimer = nil
    }

    private func handleOutputTimer() {
        guard playing else {
            return
        }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
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
    }

    private func formatTime(_ time: Double) -> String {
        let time = Int(time.rounded())
        let seconds = String(format: "%02d", time % 60)
        let minutes = time / 60
        return "\(minutes):\(seconds)"
    }
}
