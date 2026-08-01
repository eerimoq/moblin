import CoreImage
import CoreImage.CIFilterBuiltins
import MetalPetal

struct MaskEffectPoint: Equatable {
    var x: Double
    var y: Double
}

struct MaskEffectSettings: Equatable {
    var points: [MaskEffectPoint]
    var inverted: Bool
    var tension: Double
    var backgroundType: SettingsMaskBackgroundType
    var backgroundColor: RgbColor
    var backgroundColor2: RgbColor
}

private let checkerboardSquareCount: Float = 20.0

func makeCatmullRomPath(_ points: [CGPoint], tension: CGFloat) -> CGMutablePath {
    let numberOfPoints = points.count
    let path = CGMutablePath()
    path.move(to: points[0])
    for i in 0 ..< numberOfPoints {
        let point0 = points[(i - 1 + numberOfPoints) % numberOfPoints]
        let point1 = points[i]
        let point2 = points[(i + 1) % numberOfPoints]
        let point3 = points[(i + 2) % numberOfPoints]
        let cpoint1 = CGPoint(
            x: point1.x + (point2.x - point0.x) * tension,
            y: point1.y + (point2.y - point0.y) * tension
        )
        let cpoint2 = CGPoint(
            x: point2.x - (point3.x - point1.x) * tension,
            y: point2.y - (point3.y - point1.y) * tension
        )
        path.addCurve(to: point2, control1: cpoint1, control2: cpoint2)
    }
    path.closeSubpath()
    return path
}

private func makeCiColor(_ color: RgbColor) -> CIColor {
    CIColor(
        red: CGFloat(color.red) / 255.0,
        green: CGFloat(color.green) / 255.0,
        blue: CGFloat(color.blue) / 255.0
    )
}

private func makeCgColor(_ color: RgbColor) -> CGColor {
    CGColor(red: CGFloat(color.red) / 255.0,
            green: CGFloat(color.green) / 255.0,
            blue: CGFloat(color.blue) / 255.0,
            alpha: 1.0)
}

private func makeMtiColor(_ color: RgbColor) -> MTIColor {
    MTIColor(red: Float(color.red) / 255,
             green: Float(color.green) / 255,
             blue: Float(color.blue) / 255,
             alpha: 1)
}

private func makeCheckerboardImage(_ extent: CGRect, _ settings: MaskEffectSettings) -> CGImage? {
    let width = Int(extent.width)
    let height = Int(extent.height)
    guard width > 0, height > 0 else {
        return nil
    }
    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else {
        return nil
    }
    let squareSide = Double(min(width, height)) / Double(checkerboardSquareCount)
    context.setFillColor(makeCgColor(settings.backgroundColor))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(makeCgColor(settings.backgroundColor2))
    let columns = Int((Double(width) / squareSide).rounded(.up)) + 2
    let rows = Int((Double(height) / squareSide).rounded(.up)) + 2
    for row in 0 ..< rows {
        for column in 0 ..< columns where (row + column) % 2 == 1 {
            let x = Double(width) / 2 + Double(column - columns / 2) * squareSide
            let y = Double(height) / 2 + Double(row - rows / 2) * squareSide
            context.fill(CGRect(x: x, y: y, width: squareSide, height: squareSide))
        }
    }
    return context.makeImage()
}

final class MaskEffect: VideoEffect, @unchecked Sendable {
    private var settings: MaskEffectSettings?
    private var cachedSettings: MaskEffectSettings?
    private var cachedExtent: CGRect = .zero
    private var cachedMaskImage: CIImage?
    private var cachedBackgroundImage: CIImage?
    private let filterMetalPetal = MTIBlendWithMaskFilter()
    private var cachedMetalPetalSettings: MaskEffectSettings?
    private var cachedMetalPetalExtent: CGRect = .zero
    private var cachedMetalPetalMask: MTIMask?
    private var cachedMetalPetalBackgroundImage: MTIImage?

    func setSettings(settings: MaskEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
            self.cachedSettings = nil
            self.cachedMaskImage = nil
            self.cachedBackgroundImage = nil
            self.cachedMetalPetalSettings = nil
            self.cachedMetalPetalMask = nil
            self.cachedMetalPetalBackgroundImage = nil
        }
    }

    private func makeMaskImage(_ extent: CGRect, _ settings: MaskEffectSettings) -> CIImage? {
        guard let cgImage = makeMaskCgImage(extent, settings) else {
            return nil
        }
        return CIImage(cgImage: cgImage).translated(x: extent.minX, y: extent.minY)
    }

    private func makeMaskCgImage(_ extent: CGRect, _ settings: MaskEffectSettings) -> CGImage? {
        guard settings.points.count >= 3 else {
            return nil
        }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else {
            return nil
        }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        let backgroundGray: CGFloat = settings.inverted ? 1.0 : 0.0
        let polygonGray: CGFloat = settings.inverted ? 0.0 : 1.0
        context.setFillColor(gray: backgroundGray, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: polygonGray, alpha: 1.0)
        let screenPoints = settings.points.map {
            CGPoint(x: $0.x * Double(width), y: (1.0 - $0.y) * Double(height))
        }
        let path = makeCatmullRomPath(screenPoints, tension: settings.tension)
        context.addPath(path)
        context.fillPath()
        return context.makeImage()
    }

    private func makeBackgroundImage(_ extent: CGRect,
                                     _ settings: MaskEffectSettings) -> CIImage
    {
        switch settings.backgroundType {
        case .transparent:
            return CIImage.empty()
        case .solid:
            return CIImage(color: makeCiColor(settings.backgroundColor)).cropped(to: extent)
        case .checkerboard:
            let filter = CIFilter.checkerboardGenerator()
            filter.color0 = makeCiColor(settings.backgroundColor)
            filter.color1 = makeCiColor(settings.backgroundColor2)
            filter.width = Float(min(extent.width, extent.height)) / checkerboardSquareCount
            filter.sharpness = 1.0
            filter.center = CGPoint(x: extent.midX, y: extent.midY)
            return (filter.outputImage?.cropped(to: extent)) ?? CIImage.empty()
        }
    }

    private func makeMetalPetalBackgroundImage(_ extent: CGRect,
                                               _ settings: MaskEffectSettings) -> MTIImage
    {
        switch settings.backgroundType {
        case .transparent:
            return MTIImage(color: .clear, sRGB: false, size: extent.size)
        case .solid:
            return MTIImage(color: makeMtiColor(settings.backgroundColor),
                            sRGB: false,
                            size: extent.size)
        case .checkerboard:
            guard let cgImage = makeCheckerboardImage(extent, settings) else {
                return MTIImage(color: .clear, sRGB: false, size: extent.size)
            }
            return MTIImage(cgImage: cgImage, options: [.SRGB: false], isOpaque: true)
        }
    }

    override func executeMetalPetal(_ image: MTIImage, _: VideoEffectInfo) -> MTIImage {
        guard let settings else {
            return image
        }
        let extent = image.extent
        if cachedMetalPetalMask == nil || cachedMetalPetalSettings != settings
            || cachedMetalPetalExtent != extent
        {
            guard let maskCgImage = makeMaskCgImage(extent, settings) else {
                return image
            }
            cachedMetalPetalMask = MTIMask(
                content: MTIImage(cgImage: maskCgImage, options: [.SRGB: false], isOpaque: true),
                component: .red,
                mode: .normal
            )
            cachedMetalPetalBackgroundImage = makeMetalPetalBackgroundImage(extent, settings)
            cachedMetalPetalSettings = settings
            cachedMetalPetalExtent = extent
        }
        filterMetalPetal.inputImage = image
        filterMetalPetal.inputMask = cachedMetalPetalMask
        filterMetalPetal.inputBackgroundImage = cachedMetalPetalBackgroundImage
        return filterMetalPetal.outputImage ?? image
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let settings else {
            return image
        }
        let extent = image.extent
        let maskImage: CIImage
        let backgroundImage: CIImage
        if let cachedMaskImage, let cachedBackgroundImage, cachedSettings == settings,
           cachedExtent == extent
        {
            maskImage = cachedMaskImage
            backgroundImage = cachedBackgroundImage
        } else {
            guard let newMaskImage = makeMaskImage(extent, settings) else {
                return image
            }
            cachedMaskImage = newMaskImage
            cachedSettings = settings
            cachedExtent = extent
            maskImage = newMaskImage
            backgroundImage = makeBackgroundImage(extent, settings)
            cachedBackgroundImage = backgroundImage
        }
        let blender = CIFilter.blendWithMask()
        blender.inputImage = image
        blender.maskImage = maskImage
        blender.backgroundImage = backgroundImage
        return blender.outputImage ?? image
    }
}
