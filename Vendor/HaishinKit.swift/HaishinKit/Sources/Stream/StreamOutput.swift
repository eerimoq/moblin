import AVFoundation
import CoreMedia
import Foundation

/// A delegate protocol your app implements to receive capture stream output events.
public protocol StreamOutput: AnyObject, Sendable {
    /// Tells the receiver to an audio buffer outgoing.
    func stream(_ stream: some StreamConvertible, didOutput audio: AVAudioBuffer, when: AVAudioTime)
    /// Tells the receiver to a video buffer outgoing.
    func stream(_ stream: some StreamConvertible, didOutput video: CMSampleBuffer)
}
