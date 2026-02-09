import AVFAudio
import Foundation

protocol CaptureUnit {
    var lockQueue: DispatchQueue { get }
    var isSuspended: Bool { get }

    @available(tvOS 17.0, *)
    func suspend()

    @available(tvOS 17.0, *)
    func resume()

    func finish()
}
