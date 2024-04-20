import AVFoundation
import Foundation
import UIKit

class PreviewView: UIView {
    static var defaultBackgroundColor: UIColor = .black

    override public class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    override public var layer: AVSampleBufferDisplayLayer {
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

    var videoFormatDescription: CMVideoFormatDescription? {
        return currentStream?.mixer.video.formatDescription
    }

    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            currentStream?.mixer.video.videoOrientation = videoOrientation
        }
    }

    var isPortrait = false {
        didSet {
            applyIsMirrored()
        }
    }

    var isMirrored = false

    private func applyIsMirrored() {
        var transform = CGAffineTransformMakeScale(isMirrored ? -1.0 : 1.0, 1.0)
        if isPortrait {
            transform = transform.rotated(by: .pi / 2)
        }
        layer.setAffineTransform(transform)
    }

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.video.drawable = nil
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = Self.defaultBackgroundColor
        layer.backgroundColor = Self.defaultBackgroundColor.cgColor
        layer.videoGravity = videoGravity
    }
}

extension PreviewView {
    func attachStream(_ stream: NetStream?) {
        guard let stream else {
            currentStream = nil
            return
        }
        stream.lockQueue.async {
            stream.mixer.video.drawable = self
            self.currentStream = stream
            stream.mixer.startRunning()
        }
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
