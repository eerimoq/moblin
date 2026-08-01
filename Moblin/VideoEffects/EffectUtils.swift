import CoreImage
import MetalPetal
import Vision

nonisolated(unsafe) var highQualityDownsampling = false

func toPixels(_ percentage: Double, _ total: Double) -> Double {
    (percentage * total) / 100
}

func metalPetalLayerPosition(_ layout: SettingsWidgetLayout,
                             _ size: CGSize,
                             _ streamSize: CGSize) -> CGPoint
{
    var x: Double
    var y: Double
    if layout.alignment.isHorizontalCenter() {
        x = (streamSize.width - size.width) / 2
    } else if layout.alignment.isLeft() {
        x = toPixels(layout.x, streamSize.width)
    } else {
        x = streamSize.width - toPixels(layout.x, streamSize.width) - size.width
    }
    if layout.alignment.isVerticalCenter() {
        y = (streamSize.height - size.height) / 2
    } else if layout.alignment.isTop() {
        y = toPixels(layout.y, streamSize.height)
    } else {
        y = streamSize.height - toPixels(layout.y, streamSize.height) - size.height
    }
    return CGPoint(x: x + size.width / 2, y: y + size.height / 2)
}

extension MTIImage {
    func moveComposited(_ layout: SettingsWidgetLayout, _ backgroundImage: MTIImage) -> MTIImage {
        composited(layout, extent.size, false, backgroundImage, .init(contentRegion: extent))
    }

    func resizeMirrorMoveComposited(_ layout: SettingsWidgetLayout,
                                    _ mirror: Bool,
                                    _ backgroundImage: MTIImage,
                                    _ shape: MetalPetalWidgetShape) -> MTIImage
    {
        let backgroundImageSize = backgroundImage.extent.size
        let rotatedSize = shape.rotated(shape.contentRegion.size)
        let scaleX = toPixels(layout.size, backgroundImageSize.width) / rotatedSize.width
        let scaleY = toPixels(layout.size, backgroundImageSize.height) / rotatedSize.height
        let scale = min(scaleX, scaleY)
        let size = CGSize(width: shape.contentRegion.width * scale,
                          height: shape.contentRegion.height * scale)
        return composited(layout, size, mirror, backgroundImage, shape)
    }

    private func composited(_ layout: SettingsWidgetLayout,
                            _ size: CGSize,
                            _ mirror: Bool,
                            _ backgroundImage: MTIImage,
                            _ shape: MetalPetalWidgetShape) -> MTIImage
    {
        let borderWidth = shape.borderWidthPixels(size)
        let borderSize = CGSize(width: size.width + 2 * borderWidth,
                                height: size.height + 2 * borderWidth)
        let position = metalPetalLayerPosition(layout,
                                               shape.rotated(borderSize),
                                               backgroundImage.extent.size)
        let rotation = shape.rotationRadians()
        var layers: [MultilayerCompositingFilter.Layer] = []
        if borderWidth > 0 {
            layers.append(.content(.white, modifier: { layer in
                layer.size = borderSize
                layer.position = position
                layer.rotation = rotation
                layer.tintColor = shape.borderColor
                layer.cornerRadius = shape.cornerRadius(borderSize)
            }))
        }
        layers.append(.content(self, modifier: { layer in
            layer.contentRegion = shape.contentRegion
            layer.size = size
            layer.position = position
            layer.rotation = rotation
            layer.cornerRadius = shape.cornerRadius(size)
            if mirror {
                layer.contentFlipOptions = shape.mirrorFlipOptions()
            }
        }))
        let filter = MultilayerCompositingFilter()
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
        var scaleX = toPixels(layout.size, streamSize.width) / extent.size.width
        var scaleY = toPixels(layout.size, streamSize.height) / extent.size.height
        let scale = min(scaleX, scaleY)
        if mirror {
            scaleX = -scale
        } else {
            scaleX = scale
        }
        scaleY = scale
        let scaledImage = scaled(x: scaleX, y: scaleY)
        if mirror {
            return scaledImage.translated(x: scaledImage.extent.width, y: 0)
        } else {
            return scaledImage
        }
    }

    func move(_ layout: SettingsWidgetLayout, _ streamSize: CGSize) -> CIImage {
        var x: Double
        var y: Double
        if layout.alignment.isHorizontalCenter() {
            x = (streamSize.width - extent.width) / 2 - extent.minX
        } else if layout.alignment.isLeft() {
            x = toPixels(layout.x, streamSize.width) - extent.minX
        } else {
            x = streamSize.width - toPixels(layout.x, streamSize.width) - extent.width - extent.minX
            // No idea why the extra pixel is needed to get to the right.
            if x != 0 {
                x += 1
            }
        }
        if layout.alignment.isVerticalCenter() {
            y = (streamSize.height - extent.height) / 2 - extent.minY
        } else if layout.alignment.isTop() {
            y = streamSize.height - toPixels(layout.y, streamSize.height) - extent.height - extent.minY
            // No idea why the extra pixel is needed to get to the top.
            if y != 0 {
                y += 1
            }
        } else {
            y = toPixels(layout.y, streamSize.height) - extent.minY
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
