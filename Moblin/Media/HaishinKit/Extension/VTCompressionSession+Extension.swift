import Foundation
import VideoToolbox

extension VTCompressionSession {
    func prepareToEncodeFrames() -> OSStatus {
        VTCompressionSessionPrepareToEncodeFrames(self)
    }

    @inline(__always)
    func encodeFrame(
        _ imageBuffer: CVImageBuffer,
        presentationTimeStamp: CMTime,
        duration: CMTime,
        outputHandler: @escaping VTCompressionOutputHandler
    ) -> OSStatus {
        VTCompressionSessionEncodeFrame(
            self,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            frameProperties: nil,
            infoFlagsOut: nil,
            outputHandler: outputHandler
        )
    }

    func invalidate() {
        VTCompressionSessionInvalidate(self)
    }

    func setProperties(_ properties: [VTSessionProperty]) -> OSStatus {
        var dictionary: [CFString: AnyObject] = [:]
        for property in properties {
            dictionary[property.key.value] = property.value
        }
        return VTSessionSetProperties(self, propertyDictionary: dictionary as CFDictionary)
    }
}
