import AVFoundation
import Collections
import MetalPetal
import SwiftUI
import UIKit
import Vision

private let replayImagesQueue = DispatchQueue(label: "com.eerimoq.replay-effect-images")
private let replayQueue = DispatchQueue(label: "com.eerimoq.replay-effect")
private let transitionLength = 0.5

protocol ReplayEffectDelegate: AnyObject {
    func replayEffectStatus(timeLeft: Int)
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

    init(video: ReplayBufferFile, start: Double, duration: Double, size: CMVideoDimensions) {
        self.video = video
        startTime = start
        DispatchQueue.main.async {
            self.overlay = self.createOverlay(size: size)
            replayQueue.async {
                let asset = AVAsset(url: video.url)
                self.reader = try? AVAssetReader(asset: asset)
                let startTime = CMTime(seconds: start, preferredTimescale: 1000)
                let duration = CMTime(seconds: duration, preferredTimescale: 1000)
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
        let scale = Double(size.width) / (size.isPortrait() ? 1080 : 1920)
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
    private var lastImageOffset: Double?
    private var latestImage: CIImage?
    private var cancelled = false
    private var cancelledImageOffset: Double?
    private let fade: Bool
    private let duration: Double
    private var latestTimeLeft = Int.max

    init(
        video: ReplayBufferFile,
        start: Double,
        stop: Double,
        speed: Double,
        size: CMVideoDimensions,
        fade: Bool,
        delegate: ReplayEffectDelegate
    ) {
        self.speed = speed
        self.fade = fade
        self.delegate = delegate
        duration = stop - start
        reader = Reader(video: video, start: start, duration: duration, size: size)
    }

    func cancel() {
        processorPipelineQueue.async {
            self.cancelled = true
        }
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
        if cancelled {
            if cancelledImageOffset == nil {
                cancelledImageOffset = offset
            }
            return executeEnd(image, offset - cancelledImageOffset!) ?? image
        } else if let lastImageOffset {
            updateStatus(offset: offset)
            return executeEnd(image, offset - lastImageOffset) ?? image
        } else {
            updateStatus(offset: offset)
            return executeBeginAndMiddle(image, offset) ?? image
        }
    }

    private func updateStatus(offset: Double) {
        let timeLeft = max(Int((duration / speed - offset).rounded(.up)), 0)
        if timeLeft != latestTimeLeft {
            latestTimeLeft = timeLeft
            delegate?.replayEffectStatus(timeLeft: timeLeft)
        }
    }

    private func executeBeginAndMiddle(_ image: CIImage, _ offset: Double) -> CIImage? {
        let replayImage = reader.getImage(offset: offset * speed)
        latestImage = replayImage.image ?? latestImage
        if replayImage.isLast {
            lastImageOffset = offset
        } else if replayImage.image == nil {
            startPresentationTimeStamp = nil
        }
        if fade, offset <= transitionLength {
            return applyTransition(image, replayImage.image, offset)
        } else {
            return replayImage.image ?? latestImage
        }
    }

    private func executeEnd(_ image: CIImage, _ offset: Double) -> CIImage? {
        if fade, offset <= transitionLength {
            return applyTransition(latestImage, image, offset)
        } else {
            playbackCompleted = true
            if !cancelled {
                delegate?.replayEffectCompleted()
            }
            return image
        }
    }

    private func applyTransition(_ input: CIImage?, _ target: CIImage?, _ offset: Double) -> CIImage? {
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = input
        filter.targetImage = target
        filter.time = Float(offset / transitionLength)
        return filter.outputImage
    }

    override func shouldRemove() -> Bool {
        return playbackCompleted
    }
}
