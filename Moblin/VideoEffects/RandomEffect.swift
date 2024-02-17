import AVFoundation
import HaishinKit
import UIKit

let randomEffects = [
    "CIXRay",
    "CISpotLight",
    "CIColorInvert",
    "CICMYKHalftone",
    "CIDotScreen",
    "CIPhotoEffectChrome",
    "CIGaborGradients",
]

func setSpotLight(filter: CIFilter, width: CGFloat, height: CGFloat) {
    let x = width / 2
    let y = height / 2
    filter.setValue(CIVector(x: x, y: y, z: 1100), forKey: "inputLightPosition")
    filter.setValue(CIVector(x: x, y: y, z: 0), forKey: "inputLightPointsAt")
    filter.setValue(1, forKey: kCIInputBrightnessKey)
    filter.setValue(0.1, forKey: "inputConcentration")
}

final class RandomEffect: VideoEffect {
    private var filter: CIFilter?
    private var name: String

    override init() {
        name = randomEffects.shuffled().first!
        super.init()
    }

    private var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            filter = CIFilter(name: name)!
            if let filter {
                let title = CIFilter.localizedName(forFilterName: filter.name) ?? filter
                    .name
                switch name {
                case "CISpotLight":
                    setSpotLight(
                        filter: filter,
                        width: extent.width,
                        height: extent.height
                    )
                default:
                    break
                }
            }
        }
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        extent = image.extent
        guard let filter else {
            return image
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        guard let outputImage = filter.outputImage else {
            return image
        }
        if outputImage.extent != image.extent {
            return image
        }
        return outputImage
    }
}
