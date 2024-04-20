import AVFoundation
import Foundation
import UIKit

public class PreviewView: UIView {
    public static var defaultBackgroundColor: UIColor = .black

    override public class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    override public var layer: AVSampleBufferDisplayLayer {
        super.layer as! AVSampleBufferDisplayLayer
    }

    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
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

    public var videoFormatDescription: CMVideoFormatDescription? {
        return currentStream?.mixer.video.formatDescription
    }

    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            currentStream?.mixer.video.videoOrientation = videoOrientation
        }
    }

    public var isPortrait = false {
        didSet {
            applyIsMirrored()
        }
    }

    public var isMirrored = false

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

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = Self.defaultBackgroundColor
        layer.backgroundColor = Self.defaultBackgroundColor.cgColor
        layer.videoGravity = videoGravity
    }
}

extension PreviewView: NetStreamDrawable {
    public func attachStream(_ stream: NetStream?) {
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

    public func enqueue(_ sampleBuffer: CMSampleBuffer?, isFirstAfterAttach: Bool) {
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
