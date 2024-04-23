import Foundation
import VideoToolbox

extension VTDecompressionSession: VTSessionConvertible {
    static let defaultDecodeFlags: VTDecodeFrameFlags = [
        ._EnableAsynchronousDecompression,
        ._EnableTemporalProcessing,
    ]

    @discardableResult
    @inline(__always)
    func encodeFrame(
        _: CVImageBuffer,
        presentationTimeStamp _: CMTime,
        duration _: CMTime,
        outputHandler _: @escaping VTCompressionOutputHandler
    ) -> OSStatus {
        return noErr
    }

    @discardableResult
    @inline(__always)
    func decodeFrame(_ sampleBuffer: CMSampleBuffer,
                     outputHandler: @escaping VTDecompressionOutputHandler) -> OSStatus
    {
        var flagsOut: VTDecodeInfoFlags = []
        return VTDecompressionSessionDecodeFrame(
            self,
            sampleBuffer: sampleBuffer,
            flags: Self.defaultDecodeFlags,
            infoFlagsOut: &flagsOut,
            outputHandler: outputHandler
        )
    }

    func invalidate() {
        VTDecompressionSessionInvalidate(self)
    }
}
