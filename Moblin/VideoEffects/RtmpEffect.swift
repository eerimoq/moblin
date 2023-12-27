import AVFoundation
import HaishinKit
import SwiftUI
import UIKit

private let rtmpQueue = DispatchQueue(label: "com.eerimoq.widget.rtmp")

struct OverlayImage {
    var presentationTimeStamp: Double
    var image: CIImage
}

final class RtmpEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?
    private var images: [OverlayImage] = []
    private var firstPresentationTimeStamp: Double = .nan

    func addSampleBuffer(sampleBuffer: CMSampleBuffer) {
        if let buffer = sampleBuffer.imageBuffer {
            let image = OverlayImage(presentationTimeStamp: sampleBuffer.presentationTimeStamp.seconds, image: CIImage(cvPixelBuffer: buffer))
            rtmpQueue.sync {
                images.append(image)
            }
        }
    }

    private func updateOverlay(presentationTimeStamp: Double) {
        rtmpQueue.sync {
            while !images.isEmpty {
                let image = images.first!
                if firstPresentationTimeStamp.isNaN {
                    firstPresentationTimeStamp = presentationTimeStamp - image.presentationTimeStamp
                }
                if firstPresentationTimeStamp + image.presentationTimeStamp + 2 > presentationTimeStamp {
                    break
                }
                overlay = image.image
                images.remove(at: 0)
                // logger.info("rtmp-server: Present")
            }
        }
    }

    override func execute(_ image: CIImage, info: CMSampleBuffer?) -> CIImage {
        if let info  {
            updateOverlay(presentationTimeStamp: info.presentationTimeStamp.seconds)
        }
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
