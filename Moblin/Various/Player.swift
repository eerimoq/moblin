import AVFoundation

protocol PlayerDelegate: AnyObject {
    func playerOnStart(playerId: UUID)
    func playerOnStop(playerId: UUID)
    func playerOnVideoBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
    func playerOnAudioBuffer(playerId: UUID, sampleBuffer: CMSampleBuffer)
}

class Player {
    var name: String
    let id: UUID
    private var asset: AVAsset?
    private var reader: AVAssetReader?
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    private var audioTrackOutput: AVAssetReaderTrackOutput?
    var delegate: (any PlayerDelegate)?

    init(name: String, id: UUID) {
        self.name = name
        self.id = id
    }

    func start(url: URL) {
        logger.info("player: Start playing \(url)")
        asset = AVAsset(url: url)
        guard let asset else {
            return
        }
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            logger.info("player: Failed to create reader with error: \(error)")
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
                logger.info("player: Start failed")
                return
            }
            delegate?.playerOnStart(playerId: self.id)
            while let videoTrackOutput, let audioTrackOutput {
                if let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
                    delegate?.playerOnVideoBuffer(playerId: id, sampleBuffer: sampleBuffer)
                }
                if let sampleBuffer = audioTrackOutput.copyNextSampleBuffer() {
                    delegate?.playerOnAudioBuffer(playerId: id, sampleBuffer: sampleBuffer)
                }
                try? await sleep(milliSeconds: 200)
            }
            delegate?.playerOnStop(playerId: self.id)
        }
    }

    func stop() {
        reader = nil
        videoTrackOutput = nil
        audioTrackOutput = nil
    }
}
