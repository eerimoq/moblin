import AVFoundation
import CoreImage
import Foundation

/// A type that renders a screen object.
@ScreenActor
public protocol ScreenRenderer: AnyObject {
    /// The CIContext instance.
    var context: CIContext { get }
    /// The CIImage options.
    var imageOptions: [CIImageOption: Any]? { get }
    /// Specifies the backgroundColor for output video.
    var backgroundColor: CGColor { get set }
    /// The current screen bounds.
    var bounds: CGRect { get set }
    /// The current presentationTimeStamp.
    var presentationTimeStamp: CMTime { get set }
    /// The current session synchronization clock.
    var synchronizationClock: CMClock? { get set }
    /// Layouts a screen object.
    func layout(_ screenObject: ScreenObject)
    /// Draws a sceen object.
    func draw(_ screenObject: ScreenObject)
    /// Sets up the render target.
    func setTarget(_ pixelBuffer: CVPixelBuffer?)
    /// Render a screen to buffer.
    func render()
}
