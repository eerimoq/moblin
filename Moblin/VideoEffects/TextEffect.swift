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
    var speed: String = ""
    var altitude: String = ""
    var distance: String = ""
}

private enum FormatPart {
    case text(String)
    case clock
    case bitrateAndTotal
    case debugOverlay
    case speed
    case altitude
    case distance
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
                } else if formatFromIndex.hasPrefix("{speed}") {
                    loadSpeed()
                } else if formatFromIndex.hasPrefix("{altitude}") {
                    loadAltitude()
                } else if formatFromIndex.hasPrefix("{distance}") {
                    loadDistance()
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

    private func loadSpeed() {
        appendTextIfPresent()
        parts.append(.speed)
        index = format.index(index, offsetBy: 7)
        textStartIndex = index
    }

    private func loadAltitude() {
        appendTextIfPresent()
        parts.append(.altitude)
        index = format.index(index, offsetBy: 10)
        textStartIndex = index
    }

    private func loadDistance() {
        appendTextIfPresent()
        parts.append(.distance)
        index = format.index(index, offsetBy: 10)
        textStartIndex = index
    }
}

private func loadFormat(format: String) -> [FormatPart] {
    return FormatLoader().load(format: format)
}

final class TextEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private let backgroundColor: RgbColor?
    private let foregroundColor: RgbColor?
    private let fontSize: CGFloat
    private let fontDesign: Font.Design
    private let fontWeight: Font.Weight
    var x: Double
    var y: Double
    private let settingName: String
    private var stats = TextEffectStats()
    private var formatParts: [FormatPart]
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
    private var image: UIImage?
    private var imageMetalPetal: UIImage?
    private var nextUpdateTime = ContinuousClock.now
    private var nextUpdateTimeMetalPetal = ContinuousClock.now
    private var previousFormattedText: String?
    private var previousFormattedTextMetalPetal: String?

    init(
        format: String,
        backgroundColor: RgbColor?,
        foregroundColor: RgbColor?,
        fontSize: CGFloat,
        fontDesign: Font.Design,
        fontWeight: Font.Weight,
        settingName: String
    ) {
        formatParts = loadFormat(format: format)
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.fontWeight = fontWeight
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
            case .speed:
                parts.append(stats.speed)
            case .altitude:
                parts.append(stats.altitude)
            case .distance:
                parts.append(stats.distance)
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
            let formatted = self.formatted()
            guard formatted != self.previousFormattedText else {
                return
            }
            self.previousFormattedText = formatted
            let text = Text(formatted)
                .padding([.leading, .trailing], 7)
                .background(self.backgroundColor?.color() ?? .clear)
                .foregroundColor(self.foregroundColor?.color() ?? .clear)
                .font(.system(
                    size: self.scaledFontSize(width: size.width),
                    weight: self.fontWeight,
                    design: self.fontDesign
                ))
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
        let x = toPixels(self.x, size.width)
        let y = toPixels(self.y, size.height)
        overlay = CIImage(image: newImage)?
            .transformed(by: CGAffineTransform(
                translationX: x,
                y: size.height - newImage.size.height - y
            ))
            .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    }

    private func updateOverlayMetalPetal(size: CGSize) {
        guard nextUpdateTimeMetalPetal < .now else {
            return
        }
        nextUpdateTimeMetalPetal += .seconds(1)
        DispatchQueue.main.async {
            let formatted = self.formatted()
            guard formatted != self.previousFormattedTextMetalPetal else {
                return
            }
            self.previousFormattedTextMetalPetal = formatted
            let text = Text(formatted)
                .padding([.leading, .trailing], 7)
                .background(self.backgroundColor?.color() ?? .clear)
                .foregroundColor(self.foregroundColor?.color() ?? .clear)
                .font(.system(
                    size: self.scaledFontSize(width: size.width),
                    weight: self.fontWeight,
                    design: self.fontDesign
                ))
                .cornerRadius(10)
            let renderer = ImageRenderer(content: text)
            let image = renderer.uiImage
            textQueue.sync {
                self.imageMetalPetal = image
            }
        }
        var newImage: UIImage?
        textQueue.sync {
            if self.imageMetalPetal != nil {
                newImage = self.imageMetalPetal
                self.imageMetalPetal = nil
            }
        }
        guard let image = newImage?.cgImage else {
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
        updateOverlayMetalPetal(size: image.size)
        guard let overlayMetalPetal else {
            return image
        }
        let x = toPixels(self.x, image.size.width) + overlayMetalPetal.size.width / 2
        let y = toPixels(self.y, image.size.height) + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
