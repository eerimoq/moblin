//
//  IconEffect.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-31.
//

import AVFoundation
import HaishinKit
import UIKit

final class IconEffect: VideoEffect {
    let filter: CIFilter? = CIFilter(name: "CISourceOverCompositing")
    var extent = CGRect.zero {
        didSet {
            if extent == oldValue {
                return
            }
            UIGraphicsBeginImageContext(extent.size)
            var image = UIImage(named: "AppIcon.png")!
            image = image.scalePreservingAspectRatio(targetSize: CGSize(width: 50, height: 50))
            image.draw(at: CGPoint(x: extent.size.width - 55, y: extent.size.height - 55))
            icon = CIImage(image: UIGraphicsGetImageFromCurrentImageContext()!, options: nil)
            UIGraphicsEndImageContext()
        }
    }
    var icon: CIImage?

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        guard let filter = filter else {
            return image
        }
        extent = image.extent
        filter.setValue(icon!, forKey: "inputImage")
        filter.setValue(image, forKey: "inputBackgroundImage")
        return filter.outputImage!
    }
}
