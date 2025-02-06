import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        return VTCompressionSessionPrepareToEncodeFrames(self)
    }

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

    func setProperty(_ property: VTSessionProperty) -> OSStatus {
        return VTSessionSetProperty(self, key: property.key.value, value: property.value)
    }

    func setProperties(_ properties: [VTSessionProperty]) -> OSStatus {
        for property in properties {
            let err = setProperty(property)
            if err != noErr {
                return err
            }
        }
        return noErr
    }
}
