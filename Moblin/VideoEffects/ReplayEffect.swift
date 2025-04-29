import AVFoundation
import Collections
import MetalPetal
import SwiftUI
import UIKit
import Vision

private let replayImagesQueue = DispatchQueue(label: "com.eerimoq.replay-effect-images")
private let replayQueue = DispatchQueue(label: "com.eerimoq.replay-effect")

protocol ReplayEffectDelegate: AnyObject {
    func replayEffectCompleted()
}

private struct ReplayImage {
    let image: CIImage?
    let offset: Double?
    let isLast: Bool
}

private class Reader {
    private let video: ReplayBufferFile
    private let startTime: Double
    private var reader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    private let context = CIContext()
    private var images: Deque<ReplayImage> = []
    private var completed = false
    private var overlay: CIImage?

    init(video: ReplayBufferFile, start: Double, stop: Double, size: CMVideoDimensions) {
        self.video = video
        startTime = start
        DispatchQueue.main.async {
            self.overlay = self.createOverlay(size: size)
            replayQueue.async {
                let asset = AVAsset(url: video.url)
                self.reader = try? AVAssetReader(asset: asset)
                let startTime = CMTime(seconds: start, preferredTimescale: 1000)
                let duration = CMTime(seconds: stop - start, preferredTimescale: 1000)
                self.reader?.timeRange = CMTimeRange(start: startTime, duration: duration)
                asset.loadTracks(withMediaType: .video) { [weak self] tracks, error in
                    replayQueue.async {
                        self?.loadVideoTrackCompletion(tracks: tracks, error: error)
                    }
                }
            }
        }
    }

    func getImage(offset: Double) -> ReplayImage {
        return replayImagesQueue.sync {
            let image = findImage(offset: offset)
            if images.count < 10 {
                fill()
            }
            return image
        }
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
        replayImagesQueue.sync {
            images.append(ReplayImage(image: nil, offset: nil, isLast: true))
        }
    }

    private func fill() {
        replayQueue.async {
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
        replayImagesQueue.sync {
            images += newImages
        }
    }

    @MainActor
    private func createOverlay(size: CMVideoDimensions) -> CIImage? {
        let scale = Double(size.width) / 1920
        let text = HStack {
            ZStack {
                Circle()
                    .foregroundColor(.red)
                    .frame(width: 40 * scale, height: 40 * scale)
                Image(systemName: "play.fill")
                    .font(.system(size: 25 * scale))
            }
            Text("REPLAY")
                .font(.system(size: 50 * scale))
                .fontDesign(.monospaced)
        }
        .bold()
        .foregroundColor(.white)
        let renderer = ImageRenderer(content: text)
        guard let image = renderer.uiImage else {
            return nil
        }
        let x = Double(size.width) - image.size.width - 25 * scale
        let y = Double(size.height) - image.size.height - 20 * scale
        return CIImage(image: image)?.transformed(by: CGAffineTransform(translationX: x, y: y))
    }
}

final class ReplayEffect: VideoEffect {
    private var playbackCompleted = false
    private let speed: Double
    private let reader: Reader
    private var startPresentationTimeStamp: Double?
    private weak var delegate: ReplayEffectDelegate?

    init(
        video: ReplayBufferFile,
        start: Double,
        stop: Double,
        speed: Double,
        size: CMVideoDimensions,
        delegate: ReplayEffectDelegate
    ) {
        self.speed = speed
        self.delegate = delegate
        reader = Reader(video: video, start: start, stop: stop, size: size)
    }

    override func getName() -> String {
        return "replay"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let presentationTimeStamp = info.presentationTimeStamp.seconds
        if startPresentationTimeStamp == nil {
            startPresentationTimeStamp = presentationTimeStamp
        }
        let offset = info.presentationTimeStamp.seconds - startPresentationTimeStamp!
        let replayImage = reader.getImage(offset: offset * speed)
        if replayImage.isLast {
            playbackCompleted = true
            delegate?.replayEffectCompleted()
        } else if replayImage.image == nil {
            startPresentationTimeStamp = nil
        }
        return replayImage.image ?? image
    }

    override func shouldRemove() -> Bool {
        return playbackCompleted
    }
}
