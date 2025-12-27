import AVFoundation
import Collections
import CoreImage

private struct VideoImage {
    let image: CIImage
    let offset: Double
}

private let lockQueue = DispatchQueue(label: "com.eerimoq.alerts-effect")

class AlertsEffectVideoReader {
    private var images: Deque<VideoImage> = []
    private var reader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private var fillEnded: Bool = false
    private var basePresentationTimeStamp: Double?

    init(path: URL) {
        lockQueue.async {
            let asset = AVAsset(url: path)
            self.reader = try? AVAssetReader(asset: asset)
            asset.loadTracks(withMediaType: .video) { [weak self] tracks, error in
                lockQueue.async {
                    self?.loadVideoTrackCompletion(track: tracks?.first, error: error)
                }
            }
        }
    }

    func getImage(presentationTimeStamp: Double) -> CIImage? {
        if basePresentationTimeStamp == nil {
            basePresentationTimeStamp = presentationTimeStamp
        }
        let timeOffset = presentationTimeStamp - basePresentationTimeStamp!
        let image = findImage(offset: timeOffset)
        if images.count < 10 {
            fill()
        }
        return image
    }

    func hasEnded() -> Bool {
        return fillEnded && images.isEmpty
    }

    private func findImage(offset: Double) -> CIImage? {
        while let image = images.first {
            if offset <= image.offset {
                return image.image
            }
            images.removeFirst()
        }
        return nil
    }

    private func fill() {
        lockQueue.async {
            self.fillInternal()
        }
    }

    private func fillInternal() {
        guard let trackOutput else {
            return
        }
        var newImages: [VideoImage] = []
        for _ in 0 ... 10 {
            if let sampleBuffer = trackOutput.copyNextSampleBuffer(),
               let imageBuffer = sampleBuffer.imageBuffer
            {
                newImages.append(VideoImage(image: CIImage(cvImageBuffer: imageBuffer),
                                            offset: sampleBuffer.presentationTimeStamp.seconds))
            }
        }
        processorPipelineQueue.async {
            self.images += newImages
            self.fillEnded = newImages.isEmpty
        }
    }

    private func loadVideoTrackCompletion(track: AVAssetTrack?, error: (any Error)?) {
        guard error == nil, let track else {
            markFillEnded()
            return
        }
        let videoOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [String: Any]
        trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: videoOutputSettings)
        guard let trackOutput else {
            markFillEnded()
            return
        }
        reader?.add(trackOutput)
        reader?.startReading()
        fillInternal()
    }

    private func markFillEnded() {
        processorPipelineQueue.async {
            self.fillEnded = true
        }
    }
}
