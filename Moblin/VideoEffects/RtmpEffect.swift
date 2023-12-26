import AVFoundation
import HaishinKit
import SwiftUI
import UIKit

private let rtmpQueue = DispatchQueue(label: "com.eerimoq.widget.rtmp")

final class RtmpEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    var overlay: CIImage?
    var image: CIImage?

    func setImage(image: CIImage) {
        rtmpQueue.sync {
            self.image = image
        }
    }

    private func updateOverlay() {
        rtmpQueue.sync {
            if self.image != nil {
                overlay = image
                image = nil
            }
        }
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        updateOverlay()
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
