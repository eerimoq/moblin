import AVFoundation
import HaishinKit
import UIKit

final class WebViewEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    var overlay: CIImage?

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
