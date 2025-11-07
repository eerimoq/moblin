import AVFoundation
import SwiftUI
import UIKit
import Vision

final class PollEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?
    private var image: UIImage?
    private var nextUpdateTime = ContinuousClock.now.advanced(by: .seconds(-5))
    private var text = "No votes yet"

    func updateText(text: String) {
        self.text = text
    }

    override func getName() -> String {
        return "Poll widget"
    }

    private func scaledFontSize(size: CGSize) -> CGFloat {
        return 30 * (size.maximum() / 1920)
    }

    private func updateOverlay(size: CGSize) {
        guard nextUpdateTime < .now else {
            return
        }
        nextUpdateTime += .seconds(1)
        DispatchQueue.main.async {
            let content = HStack {
                Image(systemName: "chart.bar.xaxis")
                Text(self.text)
            }
            .padding([.trailing], 7)
            .background(.black.opacity(0.75))
            .foregroundStyle(.white)
            .font(.system(size: self.scaledFontSize(size: size)))
            .cornerRadius(10)
            let renderer = ImageRenderer(content: content)
            let image = renderer.uiImage
            processorPipelineQueue.async {
                self.image = image
            }
        }
        guard let newImage = image else {
            return
        }
        image = nil
        update(image: newImage, size: size)
    }

    private func update(image: UIImage, size: CGSize) {
        let x = size.width - image.size.width
        overlay = CIImage(image: image)?
            .translated(x: x - 5, y: size.height - image.size.height - 5)
            .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        updateOverlay(size: image.extent.size)
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
