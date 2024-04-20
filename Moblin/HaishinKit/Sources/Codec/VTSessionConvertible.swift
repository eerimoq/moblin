import AVFoundation
import Foundation
import VideoToolbox

protocol VTSessionConvertible {
    func setOption(_ option: VTSessionOption) -> OSStatus
    func setOptions(_ options: [VTSessionOption]) -> OSStatus
    func encodeFrame(
        _ imageBuffer: CVImageBuffer,
        presentationTimeStamp: CMTime,
        duration: CMTime,
        outputHandler: @escaping VTCompressionOutputHandler
    ) -> OSStatus
    func decodeFrame(_ sampleBuffer: CMSampleBuffer, outputHandler: @escaping VTDecompressionOutputHandler)
        -> OSStatus
    func invalidate()
}

extension VTSessionConvertible where Self: VTSession {
    func setOption(_ option: VTSessionOption) -> OSStatus {
        logger.info("setting option: \(option.key.value) \(option.value)")
        return VTSessionSetProperty(self, key: option.key.value, value: option.value)
    }

    func setOptions(_ options: [VTSessionOption]) -> OSStatus {
        for option in options {
            let err = setOption(option)
            if err != noErr {
                return err
            }
        }
        return noErr
    }
}
