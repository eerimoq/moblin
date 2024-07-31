import AVFoundation
import MetalPetal
import SDWebImage
import Vision

final class AlertEffect: VideoEffect {
    private var images: [CIImage]
    private var frameIndex = 0
    private let audioPlayer: AVAudioPlayer?
    private var onRemoved: () -> Void

    init(images: [CIImage], audioPlayer: AVAudioPlayer?, onRemoved: @escaping () -> Void) {
        self.images = images
        self.audioPlayer = audioPlayer
        self.onRemoved = onRemoved
        audioPlayer?.play()
        super.init()
    }

    override func getName() -> String {
        return "Alert widget"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        guard frameIndex < images.count else {
            return image
        }
        let image = images[frameIndex].composited(over: image)
        frameIndex += 1
        return image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard frameIndex < images.count else {
            return image
        }
        frameIndex += 1
        return image
    }

    override func shouldRemove() -> Bool {
        return frameIndex == images.count
    }

    override func removed() {
        audioPlayer?.stop()
        onRemoved()
    }
}
