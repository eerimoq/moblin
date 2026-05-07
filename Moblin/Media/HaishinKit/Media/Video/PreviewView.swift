import AVFoundation
import Foundation
import SwiftUI

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    override var layer: AVSampleBufferDisplayLayer {
        super.layer as! AVSampleBufferDisplayLayer
    }

    var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            if Thread.isMainThread {
                layer.videoGravity = videoGravity
            } else {
                DispatchQueue.main.sync {
                    layer.videoGravity = videoGravity
                }
            }
        }
    }

    var isMirrored = false

    private func applyIsMirrored() {
        layer.setAffineTransform(CGAffineTransformMakeScale(isMirrored ? -1.0 : 1.0, 1.0))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    private func setup() {
        backgroundColor = .black
        layer.backgroundColor = UIColor.black.cgColor
        layer.videoGravity = videoGravity
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer?, isFirstAfterAttach: Bool) {
        guard let sampleBuffer else {
            return
        }
        DispatchQueue.main.async {
            if self.layer.status == .failed {
                self.layer.flush()
            }
            if isFirstAfterAttach {
                self.layer.flushAndRemoveImage()
                self.applyIsMirrored()
            } else {
                self.layer.enqueue(sampleBuffer)
            }
        }
    }
}
