import AVFoundation

protocol MediaPlayerDelegate: AnyObject {
    func mediaPlayerOnLoad(playerId: UUID, name: String)
    func mediaPlayerOnUnload(playerId: UUID)
    func mediaPlayerOnPositionChanged(playerId: UUID, position: Float, time: String)
    func mediaPlayerOnVideoBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
    func mediaPlayerOnAudioBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
}

class MediaPlayer {
    private var asset: AVAsset?
    private var reader: AVAssetReader?
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    private var audioTrackOutput: AVAssetReaderTrackOutput?
    private var settings: SettingsMediaPlayer
    private var mediaStorage: MediaStorage
    private var playing = false
    private var currentFileIndex = 0
    private var fileDuration = 0.0
    private var seeking = false
    var delegate: (any MediaPlayerDelegate)?

    init(settings: SettingsMediaPlayer, mediaStorage: MediaStorage) {
        self.settings = settings.clone()
        self.mediaStorage = mediaStorage
        loadFile()
    }

    func play() {
        playing = true
    }

    func pause() {
        playing = false
    }

    func next() {
        currentFileIndex += 1
        if currentFileIndex == settings.playlist.count {
            currentFileIndex = 0
        }
        loadFile()
    }

    func previous() {
        currentFileIndex -= 1
        if currentFileIndex == -1 {
            currentFileIndex = settings.playlist.count - 1
        }
        loadFile()
    }

    func seek(position: Float) {
        logger.info("media-player: Seek \(position)")
        let time = formatTime(Double(position) / 100 * fileDuration)
        delegate?.mediaPlayerOnPositionChanged(playerId: settings.id, position: position, time: time)
    }

    func setSeeking(on: Bool) {
        seeking = on
    }

    private func loadFile() {
        guard reader == nil else {
            return
        }
        guard currentFileIndex < settings.playlist.count else {
            return
        }
        let file = settings.playlist[currentFileIndex]
        let url = mediaStorage.makePath(id: file.id)
        asset = AVAsset(url: url)
        guard let asset else {
            return
        }
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            logger.info("media-player: Failed to create reader with error: \(error)")
        }
        Task { @MainActor in
            guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
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
            reader?.add(videoTrackOutput!)
            guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else {
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
            reader?.add(audioTrackOutput!)
            guard reader?.startReading() == true else {
                logger.info("media-player: Start failed")
                return
            }
            guard let duration = try? await asset.load(.duration) else {
                logger.info("media-player: No duration")
                return
            }
            fileDuration = duration.seconds
            delegate?.mediaPlayerOnLoad(playerId: self.settings.id, name: file.name)
            let startTime = ContinuousClock.now
            while let videoTrackOutput, let audioTrackOutput {
                var time = 0.0
                if playing {
                    let now = ContinuousClock.now
                    while let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
                        delegate?.mediaPlayerOnVideoBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
                        time = sampleBuffer.presentationTimeStamp.seconds
                        if startTime
                            .advanced(by: .seconds(sampleBuffer.presentationTimeStamp.seconds)) > now
                        {
                            break
                        }
                    }
                    while let sampleBuffer = audioTrackOutput.copyNextSampleBuffer() {
                        delegate?.mediaPlayerOnAudioBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
                        if startTime
                            .advanced(by: .seconds(sampleBuffer.presentationTimeStamp.seconds)) > now
                        {
                            break
                        }
                    }
                }
                if !seeking {
                    delegate?.mediaPlayerOnPositionChanged(
                        playerId: settings.id,
                        position: Float(100 * time / fileDuration),
                        time: formatTime(time)
                    )
                }
                try? await sleep(milliSeconds: 100)
            }
            delegate?.mediaPlayerOnUnload(playerId: settings.id)
        }
    }

    private func formatTime(_ time: Double) -> String {
        let time = Int(time.rounded())
        let seconds = String(format: "%02d", time % 60)
        let minutes = time / 60
        return "\(minutes):\(seconds)"
    }
}
