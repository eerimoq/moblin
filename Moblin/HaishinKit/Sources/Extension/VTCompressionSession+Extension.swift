import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }
}

extension VTCompressionSession: VTSessionConvertible {
    @discardableResult
    @inline(__always)
    func encodeFrame(
        _ imageBuffer: CVImageBuffer,
        presentationTimeStamp: CMTime,
        duration _: CMTime,
        outputHandler: @escaping VTCompressionOutputHandler
    ) -> OSStatus {
        return VTCompressionSessionEncodeFrame(
            self,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: nil,
            outputHandler: outputHandler
        )
    }

    @discardableResult
    @inline(__always)
    func decodeFrame(_: CMSampleBuffer, outputHandler _: @escaping VTDecompressionOutputHandler) -> OSStatus {
        return noErr
    }

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }
}
