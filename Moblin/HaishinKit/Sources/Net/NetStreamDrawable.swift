import AVFoundation

protocol NetStreamDrawable: AnyObject {
    var videoOrientation: AVCaptureVideoOrientation { get set }
    var videoFormatDescription: CMVideoFormatDescription? { get }
    func attachStream(_ stream: NetStream?)
    func enqueue(_ sampleBuffer: CMSampleBuffer?, isFirstAfterAttach: Bool)
}
