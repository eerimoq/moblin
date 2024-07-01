import AVFoundation

class RecordingPlayer {
    private var asset: AVAsset?
    private var reader: AVAssetReader?
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    private var audioTrackOutput: AVAssetReaderTrackOutput?

    init() {}

    func start(url: URL) {
        logger.info("recording-player: Start playing \(url)")
        asset = AVAsset(url: url)
        guard let asset else {
            return
        }
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            logger.info("recording-player: Failed to create reader with error: \(error)")
        }
        Task { @MainActor in
            guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
                return
            }
            // print("recording-player size:", try? await videoTrack.load(.naturalSize))
            // print("recording-player fps", try? await videoTrack.load(.nominalFrameRate))
            // print("xxx format", try? await videoTrack.load(.formatDescriptions).first?.mediaType)
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
                logger.info("recording-player: Start failed")
                return
            }
            while let videoSampleBuffer = videoTrackOutput?.copyNextSampleBuffer() {
                print(
                    "recording-player video",
                    videoSampleBuffer.presentationTimeStamp.seconds,
                    videoSampleBuffer.numSamples
                )
            }
            while let audioSampleBuffer = audioTrackOutput?.copyNextSampleBuffer() {
                print(
                    "recording-player audio",
                    audioSampleBuffer.presentationTimeStamp.seconds,
                    audioSampleBuffer.numSamples
                )
            }
        }
    }

    func stop() {
        reader = nil
    }
}
