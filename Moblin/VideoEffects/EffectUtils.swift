import CoreImage
import MetalPetal
import Vision

nonisolated(unsafe) var highQualityDownsampling = false

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    (percentage * total) / 100
}

protocol EffectImage {
    func getCiImage() -> CIImage
    func getMetalPetalImage() -> MTIImage
}

final class EffectImageCgImage: EffectImage, @unchecked Sendable {
    private let source: CGImage
    private var ciImage: CIImage?
    private var metalPetalImage: MTIImage?

    init(image: CGImage) {
        source = image
    }

    func getCiImage() -> CIImage {
        if let ciImage {
            return ciImage
        }
        ciImage = CIImage(cgImage: source)
        return ciImage!
    }

    func getMetalPetalImage() -> MTIImage {
        if let metalPetalImage {
            return metalPetalImage
        }
        metalPetalImage = MTIImage(cgImage: source)
        return metalPetalImage!
    }
}

final class EffectImageCiImage: EffectImage, @unchecked Sendable {
    private let source: CIImage
    private let isOpaque: Bool
    private var metalPetalImage: MTIImage?

    init(image: CIImage, isOpaque: Bool) {
        source = image
        self.isOpaque = isOpaque
    }

    func getCiImage() -> CIImage {
        source
    }

    func getMetalPetalImage() -> MTIImage {
        if let metalPetalImage {
            return metalPetalImage
        }
        metalPetalImage = MTIImage(ciImage: source, isOpaque: isOpaque)
        return metalPetalImage!
    }
}

final class EffectImagePixelBuffer: EffectImage, @unchecked Sendable {
    private let source: CVPixelBuffer
    private var ciImage: CIImage?
    private var metalPetalImage: MTIImage?

    init(pixelBuffer: CVPixelBuffer) {
        source = pixelBuffer
    }

    func getCiImage() -> CIImage {
        if let ciImage {
            return ciImage
        }
        ciImage = CIImage(cvPixelBuffer: source)
        return ciImage!
    }

    func getMetalPetalImage() -> MTIImage {
        if let metalPetalImage {
            return metalPetalImage
        }
        metalPetalImage = MTIImage(cvPixelBuffer: source, alphaType: .premultiplied)
        return metalPetalImage!
    }
}

extension CIImage {
    func toEffectImage(isOpaque: Bool) -> EffectImageCiImage {
        EffectImageCiImage(image: self, isOpaque: isOpaque)
    }
}

extension CGImage {
    func toEffectImage() -> EffectImageCgImage {
        EffectImageCgImage(image: self)
    }
}

func layoutScale(_ layout: SettingsWidgetLayout, _ size: CGSize, _ streamSize: CGSize) -> Double {
    min(toPixels(layout.size, streamSize.width) / size.width,
        toPixels(layout.size, streamSize.height) / size.height)
}

private func layoutOffset(_ offset: Double,
                          _ size: Double,
                          _ streamSize: Double,
                          _ isCenter: Bool,
                          _ isNear: Bool) -> Double
{
    if isCenter {
        (streamSize - size) / 2
    } else if isNear {
        toPixels(offset, streamSize)
    } else {
        streamSize - toPixels(offset, streamSize) - size
    }
}

func layoutPosition(_ layout: SettingsWidgetLayout, _ size: CGSize, _ streamSize: CGSize) -> CGPoint {
    let alignment = layout.alignment
    return CGPoint(x: layoutOffset(layout.x,
                                   size.width,
                                   streamSize.width,
                                   alignment.isHorizontalCenter(),
                                   alignment.isLeft()),
                   y: layoutOffset(layout.y,
                                   size.height,
                                   streamSize.height,
                                   alignment.isVerticalCenter(),
                                   alignment.isTop()))
}

func layoutCenter(_ layout: SettingsWidgetLayout, _ size: CGSize, _ streamSize: CGSize) -> CGPoint {
    let position = layoutPosition(layout, size, streamSize)
    return CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
}

extension MTIImage {
    func moveComposited(_ layout: SettingsWidgetLayout,
                        _ backgroundImage: MTIImage,
                        _ contentRegion: CGRect? = nil) -> MTIImage
    {
        composited(layout, false, backgroundImage, .init(contentRegion: contentRegion ?? extent), false)
    }

    func positionComposited(_ position: CGPoint,
                            _ backgroundImage: MTIImage,
                            _ size: CGSize? = nil) -> MTIImage
    {
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = backgroundImage
        filter.layers = [
            .init(content: self, position: position, size: size),
        ]
        return filter.outputImage ?? backgroundImage
    }

    func resizeMirrorMoveComposited(_ layout: SettingsWidgetLayout,
                                    _ mirror: Bool,
                                    _ backgroundImage: MTIImage,
                                    _ shape: WidgetShape) -> MTIImage
    {
        composited(layout, mirror, backgroundImage, shape, true)
    }

    private func composited(_ layout: SettingsWidgetLayout,
                            _ mirror: Bool,
                            _ backgroundImage: MTIImage,
                            _ shape: WidgetShape,
                            _ resize: Bool) -> MTIImage
    {
        let placement = shape.placement(layout, backgroundImage.extent.size, resize)
        let rotation = Float(shape.rotationRadians())
        var layers: [MTILayer] = []
        if placement.borderWidth > 0 {
            layers.append(.init(content: .white,
                                position: placement.center,
                                size: placement.borderSize,
                                rotation: rotation,
                                cornerRadius: MTICornerRadius(shape.cornerRadiusPixels(placement.borderSize)),
                                tintColor: MTIColor(red: Float(shape.borderColor.red),
                                                    green: Float(shape.borderColor.green),
                                                    blue: Float(shape.borderColor.blue),
                                                    alpha: Float(shape.borderColor.alpha))))
        }
        layers.append(.init(content: self,
                            contentRegion: shape.contentRegion,
                            contentFlipOptions: mirror ? shape.mirrorFlipOptions() : [],
                            position: placement.center,
                            size: placement.size,
                            rotation: rotation,
                            cornerRadius: MTICornerRadius(shape.cornerRadiusPixels(placement.size))))
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = backgroundImage
        filter.layers = layers
        return filter.outputImage ?? backgroundImage
    }
}

extension CIImage {
    func resizeMirror(_ layout: SettingsWidgetLayout,
                      _ streamSize: CGSize,
                      _ mirror: Bool,
                      _ resize: Bool = true) -> CIImage
    {
        guard resize else {
            return self
        }
        let scale = layoutScale(layout, extent.size, streamSize)
        let scaledImage = scaled(x: mirror ? -scale : scale, y: scale)
        if mirror {
            return scaledImage.translated(x: scaledImage.extent.width, y: 0)
        } else {
            return scaledImage
        }
    }

    func move(_ layout: SettingsWidgetLayout, _ streamSize: CGSize) -> CIImage {
        let alignment = layout.alignment
        var x = layoutOffset(layout.x,
                             extent.width,
                             streamSize.width,
                             alignment.isHorizontalCenter(),
                             alignment.isLeft()) - extent.minX
        var y = layoutOffset(layout.y,
                             extent.height,
                             streamSize.height,
                             alignment.isVerticalCenter(),
                             alignment.mirrorPositionVertically()) - extent.minY
        // No idea why the extra pixel is needed to get to the right.
        if alignment.mirrorPositionHorizontally(), x != 0 {
            x += 1
        }
        // No idea why the extra pixel is needed to get to the top.
        if alignment.isTop(), y != 0 {
            y += 1
        }
        return translated(x: x, y: y)
    }

    func translated(x: Double, y: Double) -> CIImage {
        transformed(by: CGAffineTransform(translationX: x, y: y))
    }

    func scaled(x: Double, y: Double) -> CIImage {
        transformed(by: CGAffineTransform(scaleX: x, y: y), highQualityDownsample: highQualityDownsampling)
    }

    func scaledTo(size: CGSize) -> CIImage {
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let scale = min(scaleX, scaleY)
        return scaled(x: scale, y: scale)
    }

    func scaledToFill(size: CGSize) -> CIImage {
        let scaleX = size.width / extent.width
        let scaleY = size.height / extent.height
        let scale = max(scaleX, scaleY)
        return scaled(x: scale, y: scale)
    }

    func centered(size: CGSize) -> CIImage {
        let targetCenterX = size.width / 2
        let targetCenterY = size.height / 2
        let currentCenterX = extent.width / 2
        let currentCenterY = extent.height / 2
        let x = targetCenterX - currentCenterX
        let y = targetCenterY - currentCenterY
        return translated(x: x, y: y)
    }
}
