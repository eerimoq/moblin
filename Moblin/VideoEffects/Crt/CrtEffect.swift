import CoreImage

final class CrtEffect: VideoEffect {
    private let barrelFilter = CrtBarrelDistortionFilter()
    private let colorControls = CIFilter.colorControls()
    private let vignette = CIFilter.vignette()

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        let extent = image.extent
        let cropRect = CGRect(
            x: extent.width / 8,
            y: 0,
            width: 3 * extent.width / 4,
            height: extent.height
        )
        var image = image.cropped(to: cropRect)
        image = applyScanlines(image, cropRect)
        image = applyBarrelDistortion(image, extent.width)
        image = applyColors(image)
        return image.composited(over: CIImage.black.cropped(to: extent))
    }

    private func applyBarrelDistortion(_ image: CIImage, _ width: CGFloat) -> CIImage {
        barrelFilter.inputImage = image
        barrelFilter.width = width
        return barrelFilter.outputImage ?? image
    }

    private func applyColors(_ image: CIImage) -> CIImage {
        colorControls.inputImage = image
        colorControls.saturation = 0.7
        colorControls.contrast = 1.05
        colorControls.brightness = -0.02
        vignette.inputImage = colorControls.outputImage ?? image
        vignette.intensity = 2.5
        vignette.radius = 1.5
        return vignette.outputImage ?? image
    }

    private func applyScanlines(_ image: CIImage, _ cropRect: CGRect) -> CIImage {
        let scanlineWidth = max(1.0, Float(cropRect.height / 240))
        let stripes = CIFilter.stripesGenerator()
        stripes.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.25)
        stripes.color1 = CIColor.clear
        stripes.width = scanlineWidth
        stripes.sharpness = 0.3
        stripes.center = .zero
        return stripes.outputImage?
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
            .cropped(to: cropRect)
            .composited(over: image) ?? image
    }
}
