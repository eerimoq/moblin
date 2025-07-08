import AVFoundation
import Foundation
import UIKit

class PreviewView: UIView {
    private static let defaultBackgroundColor: UIColor = .black

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

    var isPortrait = false {
        didSet {
            applyIsMirrored()
        }
    }

    var isMirrored = false

    private func applyIsMirrored() {
        layer.setAffineTransform(CGAffineTransformMakeScale(isMirrored ? -1.0 : 1.0, 1.0))
    }

    init() {
        super.init(frame: .zero)
        awakeFromNib()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = Self.defaultBackgroundColor
        layer.backgroundColor = Self.defaultBackgroundColor.cgColor
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
