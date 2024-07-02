import AVFoundation

protocol MediaPlayerDelegate: AnyObject {
    func mediaPlayerOnStart(playerId: UUID)
    func mediaPlayerOnStop(playerId: UUID)
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
    var delegate: (any MediaPlayerDelegate)?

    init(settings: SettingsMediaPlayer, mediaStorage: MediaStorage) {
        self.settings = settings.clone()
        self.mediaStorage = mediaStorage
    }

    func play() {
        playing = true
        guard reader == nil else {
            return
        }
        guard let fileId = settings.playlist.first?.id else {
            return
        }
        let url = mediaStorage.makePath(id: fileId)
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
            delegate?.mediaPlayerOnStart(playerId: self.settings.id)
            let startTime = ContinuousClock.now
            while let videoTrackOutput, let audioTrackOutput {
                if playing {
                    let now = ContinuousClock.now
                    while let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
                        delegate?.mediaPlayerOnVideoBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
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
                try? await sleep(milliSeconds: 100)
            }
            delegate?.mediaPlayerOnStop(playerId: settings.id)
        }
    }

    func pause() {
        playing = false
    }

    func next() {
        logger.info("media-player: Next")
    }

    func previous() {
        logger.info("media-player: Previous")
    }

    func seek(position: Float) {
        logger.info("media-player: Seek \(position)")
    }
}
