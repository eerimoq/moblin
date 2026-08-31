import CoreImage
import UIKit

private let lowFpsImageQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.small")

final class VideoLowFpsImage {
    private let context: CIContext
    weak var processor: Processor?
    private var enabled: Bool = false
    private var interval: Double = 1.0
    private var latest: Double = 0.0
    private var frameNumber: UInt64 = 0

    init(context: CIContext) {
        self.context = context
    }

    func setFps(fps: Float) {
        interval = Double(1 / fps).clamped(to: 0.2 ... 1.0)
        enabled = fps != 0.0
        latest = 0.0
    }

    func handleImageBuffer(_ imageBuffer: CVImageBuffer, _ presentationTimeStamp: Double) {
        guard enabled else {
            return
        }
        guard presentationTimeStamp > latest + interval else {
            return
        }
        latest = presentationTimeStamp
        lowFpsImageQueue.async {
            self.createImage(imageBuffer: imageBuffer)
        }
    }

    private func createImage(imageBuffer: CVImageBuffer) {
        var ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let scale = 400.0 /
            (imageBuffer.isPortrait() ? Double(imageBuffer.height) : Double(imageBuffer.width))
        ciImage = ciImage.scaled(x: scale, y: scale)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let image = UIImage(cgImage: cgImage)
        processor?.delegate.streamLowFpsImage(
            lowFpsImage: image.jpegData(compressionQuality: 0.3),
            frameNumber: frameNumber
        )
        frameNumber += 1
    }
}
