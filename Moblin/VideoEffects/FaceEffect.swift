import AVFoundation
import MetalPetal
import SwiftUI
import Vision

private func makeFaceMask(_ ratio: Float) -> MTIMask? {
    let side = 256.0
    let filter = CIFilter.radialGradient()
    filter.center = CGPoint(x: side / 2, y: side / 2)
    filter.radius0 = Float(side / 2) / ratio
    filter.radius1 = Float(side / 2)
    filter.color0 = .white
    filter.color1 = .black
    guard let image = filter.outputImage?
        .cropped(to: CGRect(x: 0, y: 0, width: side, height: side))
    else {
        return nil
    }
    return MTIMask(
        content: image.toEffectImage(isOpaque: true).getMetalPetalImage(),
        component: .red,
        mode: .normal
    )
}

struct FaceEffectSettings {
    var blurFaces = true
    var blurText = true
    var blurBackground = true
    var showMouth = true
    var privacyMode: FaceEffectPrivacyMode = .blur(strength: 1.0)
}

enum FaceEffectPrivacyMode {
    case blur(strength: Float)
    case pixellate(strength: Float)
    case backgroundImage(CIImage?)
    case faceImage(CIImage)
}

final class FaceEffect: VideoEffect, @unchecked Sendable {
    private var settings = FaceEffectSettings()
    private let moblinImage: EffectImageCgImage?
    private var backgroundImage: EffectImageCiImage?
    private var faceMasks: [Float: MTIMask?] = [:]

    override init() {
        if let image = UIImage(named: "AppIconNoBackground"), let image = image.cgImage {
            moblinImage = image.toEffectImage()
        } else {
            moblinImage = nil
        }
    }

    func setSettings(settings: FaceEffectSettings) {
        let backgroundImage: EffectImageCiImage? = if case let .backgroundImage(image) = settings
            .privacyMode
        {
            image?.toEffectImage(isOpaque: true)
        } else {
            nil
        }
        processorPipelineQueue.async {
            self.settings = settings
            self.backgroundImage = backgroundImage
        }
    }

    override func needsFaceDetections(_: Double) -> VideoEffectDetectionsMode {
        if settings.blurFaces || settings.blurBackground || settings.showMouth {
            .now(nil)
        } else {
            .off
        }
    }

    override func needsTextDetections(_: Double) -> VideoEffectDetectionsMode {
        if settings.blurText {
            .now(nil)
        } else {
            .off
        }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let detections = info.sceneDetections() else {
            return image
        }
        var outputImage: CIImage? = image
        if (settings.blurFaces && !detections.face.isEmpty)
            || (settings.blurText && !detections.text.isEmpty)
            || settings.blurBackground
        {
            outputImage = applyBlur(
                image: image,
                detections: detections,
                blurFaces: settings.blurFaces,
                blurText: settings.blurText,
                blurBackground: settings.blurBackground
            )
        }
        if settings.showMouth {
            outputImage = addMouth(image: outputImage, detections: detections.face)
        }
        return outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        guard let detections = info.sceneDetections() else {
            return image
        }
        let blurFaces = settings.blurFaces && !detections.face.isEmpty
        let blurText = settings.blurText && !detections.text.isEmpty
        guard blurFaces || blurText || settings.blurBackground || settings.showMouth else {
            return image
        }
        guard let privacyImage = makePrivacyImageMetalPetal(image: image) else {
            return image
        }
        let backgroundImage = settings.blurBackground ? privacyImage : image
        var layers: [MTILayer] = []
        if blurFaces || settings.blurBackground {
            let facesImage = settings.blurBackground ? image : privacyImage
            layers += makeFaceLayers(image, facesImage, detections.face)
        }
        if blurText {
            layers += makeTextLayers(image, privacyImage, detections.text)
        }
        if settings.showMouth {
            layers += makeMouthLayers(image, detections.face)
        }
        guard !layers.isEmpty || settings.blurBackground else {
            return image
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = backgroundImage
        filter.layers = layers
        return filter.outputImage ?? image
    }

    private func makePrivacyImageMetalPetal(image: MTIImage) -> MTIImage? {
        switch settings.privacyMode {
        case let .blur(strength: strength):
            let filter = MTIMPSGaussianBlurFilter()
            filter.inputImage = image
            filter.radius = Float(image.extent.width / 50.0) * strength
            return filter.outputImage
        case let .pixellate(strength: strength):
            let filter = MTIPixellateFilter()
            filter.inputImage = image
            let scale = pixellateCalcScale(size: image.extent.size, strength: strength)
            filter.scale = simd_make_float2(scale, scale)
            return filter.outputImage
        case .backgroundImage:
            guard let backgroundImage = backgroundImage?.getMetalPetalImage() else {
                return nil
            }
            let size = image.extent.size
            let scale = max(size.width / backgroundImage.extent.width,
                            size.height / backgroundImage.extent.height)
            return backgroundImage.positionComposited(
                CGPoint(x: size.width / 2, y: size.height / 2),
                image,
                CGSize(width: backgroundImage.extent.width * scale,
                       height: backgroundImage.extent.height * scale)
            )
        case .faceImage:
            return nil
        }
    }

    private func makeFaceLayers(_ image: MTIImage,
                                _ facesImage: MTIImage,
                                _ detections: [VNFaceObservation]) -> [MTILayer]
    {
        let ratio: Float = switch settings.privacyMode {
        case .blur, .pixellate:
            1.5
        case .backgroundImage:
            1.2
        case .faceImage:
            1
        }
        if faceMasks[ratio] == nil {
            faceMasks[ratio] = makeFaceMask(ratio)
        }
        guard let mask = faceMasks[ratio] ?? nil else {
            return []
        }
        let size = image.extent.size
        return detections.compactMap { detection in
            guard let boundingBox = detection.stableBoundingBox(imageSize: size) else {
                return nil
            }
            let side = 2 * Double(ratio) * boundingBox.height / 1.7
            let position = CGPoint(x: boundingBox.midX, y: size.height - boundingBox.midY)
            return .init(content: facesImage,
                         contentRegion: CGRect(x: position.x - side / 2,
                                               y: position.y - side / 2,
                                               width: side,
                                               height: side),
                         mask: mask,
                         position: position,
                         size: CGSize(width: side, height: side))
        }
    }

    private func makeTextLayers(_ image: MTIImage,
                                _ privacyImage: MTIImage,
                                _ detections: [TextDetection]) -> [MTILayer]
    {
        let size = image.extent.size
        return detections.map { detection in
            let boundingBox = CGRect(x: detection.boundingBox.origin.x * 1920,
                                     y: detection.boundingBox.origin.y * 1080,
                                     width: detection.boundingBox.width * 1920,
                                     height: detection.boundingBox.height * 1080)
            let contentRegion = CGRect(x: boundingBox.minX,
                                       y: size.height - boundingBox.maxY,
                                       width: boundingBox.width,
                                       height: boundingBox.height)
            return .init(content: privacyImage,
                         contentRegion: contentRegion,
                         position: CGPoint(x: contentRegion.midX, y: contentRegion.midY),
                         size: contentRegion.size)
        }
    }

    private func makeMouthLayers(_ image: MTIImage,
                                 _ detections: [VNFaceObservation]) -> [MTILayer]
    {
        guard let moblinImage = moblinImage?.getMetalPetalImage() else {
            return []
        }
        let size = image.extent.size
        return detections.compactMap { detection in
            guard let mouth = calcMouth(detection, size, moblinImage.extent.size) else {
                return nil
            }
            return .init(content: moblinImage,
                         position: CGPoint(x: mouth.midX, y: size.height - mouth.midY),
                         size: mouth.size)
        }
    }

    private func makePrivacyImage(image: CIImage) -> CIImage? {
        switch settings.privacyMode {
        case let .blur(strength: strength):
            return image
                .applyingGaussianBlur(sigma: (image.extent.width / 50.0) * Double(strength))
                .cropped(to: image.extent)
        case let .pixellate(strength: strength):
            let filter = CIFilter.pixellate()
            filter.inputImage = image
            filter.center = .zero
            filter.scale = pixellateCalcScale(size: image.extent.size, strength: strength)
            return filter.outputImage?.cropped(to: image.extent) ?? image
        case let .backgroundImage(backgroundImage):
            return backgroundImage?
                .scaledToFill(size: image.extent.size)
                .cropped(to: image.extent)
        case .faceImage:
            return nil
        }
    }

    private func createFacesMaskImage(imageExtent: CGRect, detections: [VNFaceObservation]) -> CIImage? {
        var mask = CIImage.empty().cropped(to: imageExtent)
        for detection in detections {
            guard let boundingBox = detection.stableBoundingBox(imageSize: imageExtent.size) else {
                continue
            }
            let faceCenter = CGPoint(x: boundingBox.maxX - (boundingBox.width / 2),
                                     y: boundingBox.maxY - (boundingBox.height / 2))
            let faceMask = CIFilter.radialGradient()
            faceMask.center = faceCenter
            faceMask.radius0 = Float(boundingBox.height / 1.7)
            switch settings.privacyMode {
            case .blur:
                faceMask.radius1 = faceMask.radius0 * 1.5
            case .pixellate:
                faceMask.radius1 = faceMask.radius0 * 1.5
            case .backgroundImage:
                faceMask.radius1 = faceMask.radius0 * 1.2
            case .faceImage:
                faceMask.radius1 = faceMask.radius0
            }
            faceMask.color0 = CIColor.white
            faceMask.color1 = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
            guard let faceMask = faceMask.outputImage?.cropped(to: boundingBox.insetBy(
                dx: -boundingBox.width / 2,
                dy: -boundingBox.height / 2
            )) else {
                continue
            }
            mask = faceMask.composited(over: mask)
        }
        return mask
    }

    private func createTextsMaskImage(imageExtent: CGRect, detections: [TextDetection]) -> CIImage? {
        var mask = CIImage.empty().cropped(to: imageExtent)
        for detection in detections {
            let x = detection.boundingBox.origin.x * 1920
            let y = detection.boundingBox.origin.y * 1080
            let width = detection.boundingBox.width * 1920
            let height = detection.boundingBox.height * 1080
            let boundingBox = CGRect(x: x, y: y, width: width, height: height)
            mask = CIImage(color: .white)
                .cropped(to: boundingBox)
                .composited(over: mask)
        }
        return mask
    }

    private func applyBlur(image: CIImage,
                           detections: Detections,
                           blurFaces: Bool,
                           blurText: Bool,
                           blurBackground: Bool) -> CIImage?
    {
        let privacyImage = makePrivacyImage(image: image)
        var outputImage: CIImage? = image
        if (blurFaces && !detections.face.isEmpty) || blurBackground {
            let mask = createFacesMaskImage(imageExtent: image.extent, detections: detections.face)
            if blurFaces {
                let blender = CIFilter.blendWithMask()
                blender.inputImage = privacyImage
                blender.backgroundImage = image
                blender.maskImage = mask
                outputImage = blender.outputImage
            }
            if blurBackground {
                let blender = CIFilter.blendWithMask()
                blender.inputImage = outputImage
                blender.backgroundImage = privacyImage
                blender.maskImage = mask
                outputImage = blender.outputImage
            }
        }
        if blurText, !detections.text.isEmpty {
            let mask = createTextsMaskImage(imageExtent: image.extent, detections: detections.text)
            let blender = CIFilter.blendWithMask()
            blender.inputImage = privacyImage
            blender.backgroundImage = outputImage
            blender.maskImage = mask
            outputImage = blender.outputImage
        }
        return outputImage
    }

    private func calcMouth(_ detection: VNFaceObservation,
                           _ imageSize: CGSize,
                           _ moblinImageSize: CGSize) -> CGRect?
    {
        guard let innerLips = detection.landmarks?.innerLips else {
            return nil
        }
        let points = innerLips.pointsInImage(imageSize: imageSize)
        guard let firstPoint = points.first else {
            return nil
        }
        var minX = firstPoint.x
        var maxX = firstPoint.x
        var minY = firstPoint.y
        var maxY = firstPoint.y
        for point in points {
            minX = min(point.x, minX)
            maxX = max(point.x, maxX)
            minY = min(point.y, minY)
            maxY = max(point.y, maxY)
        }
        let diffX = maxX - minX
        let diffY = maxY - minY
        guard diffY > diffX else {
            return nil
        }
        let height = moblinImageSize.height * (diffX / moblinImageSize.width)
        return CGRect(x: minX, y: minY + (diffY - height) / 2, width: diffX, height: height)
    }

    private func addMouth(image: CIImage?, detections: [VNFaceObservation]?) -> CIImage? {
        guard let image, let detections, let moblinImage = moblinImage?.getCiImage() else {
            return image
        }
        var outputImage = image
        for detection in detections {
            guard let mouth = calcMouth(detection, image.extent.size, moblinImage.extent.size) else {
                continue
            }
            let scale = mouth.width / moblinImage.extent.width
            outputImage = moblinImage
                .scaled(x: scale, y: scale)
                .translated(x: mouth.minX, y: mouth.minY)
                .composited(over: outputImage)
        }
        return outputImage.cropped(to: image.extent)
    }
}
