import CoreImage
import CoreImage.CIFilterBuiltins

final class FourThreeEffect: VideoEffect {
    private let barrelFilter = FourThreeFilter()
    private let colorControls = CIFilter.colorControls()
    private let vignette = CIFilter.vignette()

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let extent = image.extent
        let cropRect = CGRect(
            x: extent.width / 8,
            y: 0,
            width: 3 * extent.width / 4,
            height: extent.height
        )

        // Crop to 4:3 aspect ratio
        var result = image.cropped(to: cropRect)

        // Barrel distortion (CRT curvature - convex outward)
        barrelFilter.inputImage = result
        result = barrelFilter.outputImage?.cropped(to: cropRect) ?? result

        // Slight color degradation (aged look)
        colorControls.inputImage = result
        colorControls.saturation = 0.7
        colorControls.contrast = 1.05
        colorControls.brightness = -0.02
        result = colorControls.outputImage ?? result

        // Vignette (darkened edges like CRT)
        vignette.inputImage = result
        vignette.intensity = 1.5
        vignette.radius = 2.0
        result = vignette.outputImage ?? result

        // Horizontal scanlines (vague horizontal lines for old TV look)
        result = applyScanlines(result, cropRect)

        // Film grain (animated noise for old video look)
        result = applyFilmGrain(result, cropRect, info)

        // Composite over black background
        return result.composited(over: CIImage.black.cropped(to: extent))
    }

    private func applyScanlines(_ image: CIImage, _ cropRect: CGRect) -> CIImage {
        let scanlineWidth = max(1.0, Float(cropRect.height / 540))
        let stripes = CIFilter.stripesGenerator()
        stripes.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.1)
        stripes.color1 = CIColor.clear
        stripes.width = scanlineWidth
        stripes.sharpness = 0.3
        stripes.center = .zero
        guard let scanlines = stripes.outputImage?
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
            .cropped(to: cropRect)
        else {
            return image
        }
        return scanlines.composited(over: image)
    }

    private func applyFilmGrain(_ image: CIImage, _ cropRect: CGRect,
                                _ info: VideoEffectInfo) -> CIImage
    {
        let noiseGenerator = CIFilter.randomGenerator()
        guard let noiseImage = noiseGenerator.outputImage else {
            return image
        }
        // Animate noise by shifting based on time
        let time = info.presentationTimeStamp.seconds
        let offset = CGAffineTransform(
            translationX: CGFloat(sin(time * 7) * 100),
            y: CGFloat(cos(time * 11) * 100)
        )
        let animatedNoise = noiseImage
            .transformed(by: offset)
            .cropped(to: cropRect)
        // Convert to dim monochromatic noise
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = animatedNoise
        colorMatrix.rVector = CIVector(x: 0.01, y: 0.01, z: 0.01, w: 0)
        colorMatrix.gVector = CIVector(x: 0.01, y: 0.01, z: 0.01, w: 0)
        colorMatrix.bVector = CIVector(x: 0.01, y: 0.01, z: 0.01, w: 0)
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.biasVector = CIVector(x: -0.015, y: -0.015, z: -0.015, w: 0)
        guard let dimmedNoise = colorMatrix.outputImage else {
            return image
        }
        let blend = CIFilter.additionCompositing()
        blend.inputImage = dimmedNoise
        blend.backgroundImage = image
        return blend.outputImage?.cropped(to: cropRect) ?? image
    }
}
