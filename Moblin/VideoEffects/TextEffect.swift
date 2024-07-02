import AVFoundation
import MetalPetal
import SwiftUI
import UIKit
import Vision

private let textQueue = DispatchQueue(label: "com.eerimoq.widget.text")

struct TextEffectStats {
    var bitrateAndTotal: String = ""
    var date = Date()
    var debugOverlayLines: [String] = []
}

private enum FormatPart {
    case text(String)
    case clock
    case bitrateAndTotal
    case debugOverlay
}

private class FormatLoader {
    private var format: String = ""
    private var parts: [FormatPart] = []
    private var index: String.Index!
    private var textStartIndex: String.Index!

    func load(format inputFormat: String) -> [FormatPart] {
        format = inputFormat.replacing("\\n", with: "\n")
        parts = []
        index = format.startIndex
        textStartIndex = format.startIndex
        while index < format.endIndex {
            switch format[index] {
            case "{":
                let formatFromIndex = format[index ..< format.endIndex].lowercased()
                if formatFromIndex.hasPrefix("{time}") {
                    loadTime()
                } else if formatFromIndex.hasPrefix("{bitrateandtotal}") {
                    loadBitrateAndTotal()
                } else if formatFromIndex.hasPrefix("{debugoverlay}") {
                    loadDebugOverlay()
                } else {
                    index = format.index(after: index)
                }
            default:
                index = format.index(after: index)
            }
        }
        appendTextIfPresent()
        return parts
    }

    private func appendTextIfPresent() {
        if textStartIndex < index {
            parts.append(.text(String(format[textStartIndex ..< index])))
        }
    }

    private func loadTime() {
        appendTextIfPresent()
        parts.append(.clock)
        index = format.index(index, offsetBy: 6)
        textStartIndex = index
    }

    private func loadBitrateAndTotal() {
        appendTextIfPresent()
        parts.append(.bitrateAndTotal)
        index = format.index(index, offsetBy: 17)
        textStartIndex = index
    }

    private func loadDebugOverlay() {
        appendTextIfPresent()
        parts.append(.debugOverlay)
        index = format.index(index, offsetBy: 14)
        textStartIndex = index
    }
}

private func loadFormat(format: String) -> [FormatPart] {
    return FormatLoader().load(format: format)
}

final class TextEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var fontSize: CGFloat
    var x: Double
    var y: Double
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
    private var image: UIImage?
    private let settingName: String
    private var nextUpdateTime = ContinuousClock.now
    private var stats = TextEffectStats()
    private var formatParts: [FormatPart]

    init(format: String, fontSize: CGFloat, settingName: String) {
        formatParts = loadFormat(format: format)
        self.fontSize = fontSize
        self.settingName = settingName
        x = 0
        y = 0
        super.init()
    }

    func updateStats(stats: TextEffectStats) {
        self.stats = stats
    }

    override func getName() -> String {
        return "\(settingName) text widget"
    }

    private func formatted() -> String {
        var parts: [String] = []
        for formatPart in formatParts {
            switch formatPart {
            case let .text(text):
                parts.append(text)
            case .clock:
                parts.append(stats.date.formatted(.dateTime.hour().minute().second()))
            case .bitrateAndTotal:
                parts.append(stats.bitrateAndTotal)
            case .debugOverlay:
                parts.append(stats.debugOverlayLines.joined(separator: "\n"))
            }
        }
        return parts.joined()
    }

    private func scaledFontSize(width: Double) -> CGFloat {
        return fontSize * (width / 1920)
    }

    private func updateOverlay(size: CGSize) {
        guard nextUpdateTime < .now else {
            return
        }
        nextUpdateTime += .seconds(1)
        DispatchQueue.main.async {
            let text = Text(self.formatted())
                .padding([.leading, .trailing], 7)
                .background(.black)
                .foregroundColor(.white)
                .font(.system(size: self.scaledFontSize(width: size.width)))
                .cornerRadius(10)
            let renderer = ImageRenderer(content: text)
            let image = renderer.uiImage
            textQueue.sync {
                self.image = image
            }
        }
        var newImage: UIImage?
        textQueue.sync {
            if self.image != nil {
                newImage = self.image
                self.image = nil
            }
        }
        guard let newImage else {
            return
        }
        update(image: newImage, size: size)
        updateMetalPetal(image: newImage, size: size)
    }

    private func update(image: UIImage, size: CGSize) {
        let x = (size.width * self.x) / 100
        let y = (size.height * self.y) / 100
        overlay = CIImage(image: image)?
            .transformed(by: CGAffineTransform(
                translationX: x,
                y: size.height - image.size.height - y
            ))
            .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    private func updateMetalPetal(image: UIImage, size _: CGSize) {
        guard let image = image.cgImage else {
            return
        }
        overlayMetalPetal = MTIImage(cgImage: image, isOpaque: true)
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        updateOverlay(size: image.extent.size)
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let image else {
            return image
        }
        updateOverlay(size: image.size)
        guard let overlayMetalPetal else {
            return image
        }
        let x = (image.size.width * self.x) / 100 + overlayMetalPetal.size.width / 2
        let y = (image.size.height * self.y) / 100 + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
