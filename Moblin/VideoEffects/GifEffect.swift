import AVFoundation
import MetalPetal
import SDWebImage
import Vision

final class GifEffect: VideoEffect {
    private var images: [CIImage]
    private var frameIndex = 0

    init(fps: Double) {
        images = []
        var fpsTime = 0.0
        var gifTime = 0.0
        if let path = Bundle.main.path(forResource: "LUTs.bundle/h.gif", ofType: nil),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let animatedImage = SDAnimatedImage(data: data)
        {
            for index in 0 ..< animatedImage.animatedImageFrameCount {
                if let cgImage = animatedImage.animatedImageFrame(at: index)?.cgImage {
                    gifTime += animatedImage.animatedImageDuration(at: index)
                    let image = CIImage(cgImage: cgImage)
                    while fpsTime < gifTime {
                        images.append(image)
                        fpsTime += 1 / fps
                    }
                }
            }
        }
        super.init()
    }

    override func getName() -> String {
        return "GIF widget"
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        let image = images[frameIndex].composited(over: image)
        frameIndex += 1
        return image
    }

    override func executeMetalPetal(_: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        frameIndex += 1
        return nil
    }

    override func shouldRemove() -> Bool {
        return frameIndex == images.count
    }
}
