import AVFoundation
import Collections
import CoreImage
import SwiftUI

struct ReplayImage {
    let image: CIImage?
    let offset: Double?
    let isLast: Bool
}

class ReplayEffectReplayReader {
    private let video: ReplayBufferFile
    private let startTime: Double
    private var reader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private let context = CIContext()
    private var images: Deque<ReplayImage> = []
    private var completed = false
    private var overlay: CIImage?
    private let size: CGSize

    init(video: ReplayBufferFile, start: Double, duration: Double, size: CMVideoDimensions) {
        self.video = video
        self.size = size.toSize()
        startTime = start
        DispatchQueue.main.async {
            self.overlay = self.createOverlay(size: size)
            replayEffectQueue.async {
                let asset = AVAsset(url: video.url)
                self.reader = try? AVAssetReader(asset: asset)
                let startTime = CMTime(seconds: start)
                let duration = CMTime(seconds: duration)
                self.reader?.timeRange = CMTimeRange(start: startTime, duration: duration)
                asset.loadTracks(withMediaType: .video) { [weak self] tracks, error in
                    replayEffectQueue.async {
                        self?.loadVideoTrackCompletion(tracks: tracks, error: error)
                    }
                }
            }
        }
    }

    func getImage(offset: Double) -> ReplayImage {
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

    private func loadVideoTrackCompletion(tracks: [AVAssetTrack]?, error: (any Error)?) {
        guard error == nil, let track = tracks?.first else {
            markCompleted()
            return
        }
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: true,
        ] as [String: Any]
        trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        guard let trackOutput else {
            markCompleted()
            return
        }
        reader?.add(trackOutput)
        reader?.startReading()
        fillInternal()
    }

    private func markCompleted() {
        processorPipelineQueue.async {
            self.images.append(ReplayImage(image: nil, offset: nil, isLast: true))
        }
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
                var image = CIImage(cvImageBuffer: imageBuffer)
                    .scaledTo(size: size)
                    .centered(size: size)
                    .composited(over: CIImage.black.cropped(to: CGRect(origin: .zero, size: size)))
                if let overlay {
                    image = overlay.composited(over: image)
                }
                newImages.append(ReplayImage(
                    image: image,
                    offset: sampleBuffer.presentationTimeStamp.seconds - startTime,
                    isLast: false
                ))
            } else {
                newImages.append(ReplayImage(image: nil, offset: nil, isLast: true))
                break
            }
        }
        processorPipelineQueue.async {
            self.images += newImages
        }
    }

    @MainActor
    private func createOverlay(size: CMVideoDimensions) -> CIImage? {
        let scale = Double(size.width) / (size.isPortrait() ? 1080 : 1920)
        let text = HStack {
            ZStack {
                Circle()
                    .foregroundStyle(.red)
                    .frame(width: 40 * scale, height: 40 * scale)
                Image(systemName: "play.fill")
                    .font(.system(size: 25 * scale))
            }
            Text("REPLAY")
                .font(.system(size: 50 * scale))
                .fontDesign(.monospaced)
        }
        .bold()
        .foregroundStyle(.white)
        let renderer = ImageRenderer(content: text)
        guard let image = renderer.uiImage else {
            return nil
        }
        let x = Double(size.width) - image.size.width - 25 * scale
        let y = Double(size.height) - image.size.height - 20 * scale
        return CIImage(image: image)?.translated(x: x, y: y)
    }
}
