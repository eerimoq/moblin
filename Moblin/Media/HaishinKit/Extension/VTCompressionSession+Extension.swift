import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        return VTCompressionSessionPrepareToEncodeFrames(self)
    }

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

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }

    func setOption(_ option: VTSessionOption) -> OSStatus {
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
