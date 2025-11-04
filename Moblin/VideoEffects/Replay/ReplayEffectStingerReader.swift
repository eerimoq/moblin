import AVFoundation
import Collections
import CoreImage

class ReplayEffectStingerReader {
    private var images: Deque<ReplayImage> = []
    private var reader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private(set) var duration: Double = 0
    private(set) var setupCompleted: Bool = false

    init(path: URL) {
        setup(path: path)
    }

    func getImage(offset: Double) -> ReplayImage? {
        let image = findImage(offset: offset)
        if images.count < 10 {
            fill()
        }
        return image
    }

    private func findImage(offset: Double) -> ReplayImage {
        while let image = images.first {
            if let imageOffset = image.offset {
                if offset < imageOffset {
                    return image
                }
            } else {
                return image
            }
            images.removeFirst()
        }
        return ReplayImage(image: nil, offset: nil, isLast: false)
    }

    private func fill() {
        replayEffectQueue.async {
            self.fillInternal()
        }
    }

    private func fillInternal() {
        guard let trackOutput else {
            return
        }
        var newImages: [ReplayImage] = []
        for _ in 0 ... 10 {
            if let sampleBuffer = trackOutput.copyNextSampleBuffer(), let imageBuffer = sampleBuffer.imageBuffer {
                let image = CIImage(cvImageBuffer: imageBuffer)
                newImages.append(ReplayImage(image: image,
                                             offset: sampleBuffer.presentationTimeStamp.seconds,
                                             isLast: false))
            } else {
                newImages.append(ReplayImage(image: nil, offset: nil, isLast: true))
                break
            }
        }
        processorPipelineQueue.async {
            self.images += newImages
        }
    }

    private func setup(path: URL) {
        replayEffectQueue.async {
            let asset = AVAsset(url: path)
            self.reader = try? AVAssetReader(asset: asset)
            self.duration = asset.duration()
            asset.loadTracks(withMediaType: .video) { [weak self] tracks, error in
                replayEffectQueue.async {
                    self?.loadVideoTrackCompletion(track: tracks?.first, error: error)
                }
            }
        }
    }

    private func loadVideoTrackCompletion(track: AVAssetTrack?, error: (any Error)?) {
        guard error == nil, let track else {
            setupComplete()
            return
        }
        let videoOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [String: Any]
        trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: videoOutputSettings)
        guard let trackOutput else {
            setupComplete()
            return
        }
        reader?.add(trackOutput)
        reader?.startReading()
        fillInternal()
        setupComplete()
    }

    private func setupComplete() {
        processorPipelineQueue.async {
            self.setupCompleted = true
        }
    }
}
