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
    var delegate: (any MediaPlayerDelegate)?

    init(settings: SettingsMediaPlayer) {
        self.settings = settings.clone()
    }

    func play(url: URL) {
        logger.info("media-player: Start playing \(url)")
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
            while let videoTrackOutput, let audioTrackOutput {
                if let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
                    delegate?.mediaPlayerOnVideoBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
                }
                if let sampleBuffer = audioTrackOutput.copyNextSampleBuffer() {
                    delegate?.mediaPlayerOnAudioBuffer(playerId: settings.id, sampleBuffer: sampleBuffer)
                }
                try? await sleep(milliSeconds: 200)
            }
            delegate?.mediaPlayerOnStop(playerId: settings.id)
        }
    }

    func stop() {
        reader = nil
        videoTrackOutput = nil
        audioTrackOutput = nil
    }
}
