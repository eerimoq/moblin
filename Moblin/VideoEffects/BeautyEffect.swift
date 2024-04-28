import AVFoundation
import UIKit
import Vision

final class BeautyEffect: VideoEffect {
    var blur = true
    var colors = true
    var contrast: Float = 1.0
    var brightness: Float = 0.0
    var saturation: Float = 1.0

    override func getName() -> String {
        return "beauty filter"
    }

    override func needsFaceDetections() -> Bool {
        return true
    }

    private func createFacesMaskImage(imageExtent: CGRect, detections: [VNFaceObservation]) -> CIImage? {
        var facesMask = CIImage.empty().cropped(to: imageExtent)
        for detection in detections {
            let faceBoundingBox = CGRect(x: detection.boundingBox.minX * imageExtent.width,
                                         y: detection.boundingBox.minY * imageExtent.height,
                                         width: detection.boundingBox.width * imageExtent.width,
                                         height: detection.boundingBox.height * imageExtent.height)
            let faceCenter = CGPoint(x: faceBoundingBox.maxX - (faceBoundingBox.width / 2),
                                     y: faceBoundingBox.maxY - (faceBoundingBox.height / 2))
            let faceMask = CIFilter.radialGradient()
            faceMask.center = faceCenter
            faceMask.radius0 = Float(faceBoundingBox.height / 2)
            faceMask.radius1 = Float(faceBoundingBox.height)
            faceMask.color0 = CIColor.white
            faceMask.color1 = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
            guard let faceMask = faceMask.outputImage?.cropped(to: faceBoundingBox.insetBy(
                dx: -faceBoundingBox.width / 2,
                dy: -faceBoundingBox.height / 2
            )) else {
                continue
            }
            facesMask = faceMask.composited(over: facesMask)
        }
        return facesMask
    }

    /* private func adjustGamma(image: CIImage?) -> CIImage? {
         let filter = CIFilter.gammaAdjust()
         filter.inputImage = image
         filter.power = 1
         return filter.outputImage
     }

     private func adjustHue(image: CIImage?) -> CIImage? {
         let filter = CIFilter.hueAdjust()
         filter.inputImage = image
         filter.angle = 5
         return filter.outputImage
     }

     private func adjustExposure(image: CIImage?) -> CIImage? {
         let filter = CIFilter.exposureAdjust()
         filter.inputImage = image
         filter.ev = 2
         return filter.outputImage
     }

     private func adjustVibrance(image: CIImage?) -> CIImage? {
         let filter = CIFilter.vibrance()
         filter.inputImage = image
         filter.amount = 2
         return filter.outputImage
     } */

    private func adjustColorControls(image: CIImage?) -> CIImage? {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = brightness
        filter.contrast = contrast
        filter.saturation = saturation
        return filter.outputImage
    }

    private func applyBlur(image: CIImage?, facesMaskImage: CIImage?) -> CIImage? {
        guard let image else {
            return image
        }
        let maskImage = image
            .clampedToExtent()
            .applyingGaussianBlur(sigma: image.extent.width / 50.0)
            .cropped(to: image.extent)
        let faceBlender = CIFilter.blendWithMask()
        faceBlender.inputImage = maskImage
        faceBlender.backgroundImage = image
        faceBlender.maskImage = facesMaskImage
        return faceBlender.outputImage
    }

    private func adjustColors(image: CIImage?, facesMaskImage: CIImage?) -> CIImage? {
        // outputImage = adjustHue(image: outputImage)
        // outputImage = adjustGamma(image: outputImage)
        // outputImage = adjustExposure(image: outputImage)
        // outputImage = adjustVibrance(image: outputImage)
        let colorImage = adjustColorControls(image: image)
        let faceBlender = CIFilter.blendWithMask()
        faceBlender.inputImage = colorImage
        faceBlender.backgroundImage = image
        faceBlender.maskImage = facesMaskImage
        return faceBlender.outputImage
    }

    override func execute(_ image: CIImage, _ faceDetections: [VNFaceObservation]?) -> CIImage {
        guard let faceDetections else {
            return image
        }
        var outputImage: CIImage? = image
        let facesMaskImage = createFacesMaskImage(imageExtent: image.extent, detections: faceDetections)
        if colors {
            outputImage = adjustColors(image: outputImage, facesMaskImage: facesMaskImage)
        }
        if blur {
            outputImage = applyBlur(image: outputImage, facesMaskImage: facesMaskImage)
        }
        let scaleDownFactor = 0.8
        let width = image.extent.width
        let height = image.extent.height
        let scaleUpFactor = 1 / scaleDownFactor
        let smallWidth = width * scaleDownFactor
        let smallHeight = height * scaleDownFactor
        let smallOffsetX = (width - smallWidth) / 2
        let smallOffsetY = (height - smallHeight) / 2
        outputImage = outputImage?
            .cropped(to: CGRect(x: smallOffsetX, y: smallOffsetY, width: smallWidth, height: smallHeight))
            .transformed(by: CGAffineTransform(translationX: -smallOffsetX, y: -smallOffsetY))
            .transformed(by: CGAffineTransform(scaleX: scaleUpFactor, y: scaleUpFactor))
            .cropped(to: image.extent)
        return outputImage ?? image
    }
}
