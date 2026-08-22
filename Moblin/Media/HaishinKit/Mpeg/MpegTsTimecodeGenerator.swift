import CoreMedia
import Foundation

struct MpegTsTimecode {
    let clock: Date
    let frame: UInt32
}

class MpegTsTimecodeGenerator {
    private var presentationTimeStampBase: Double?
    private var previousDecodeTimeStamp: Double?
    private var estimatedFrameDuration: Double = 0.033
    private var offsetingFrames: Bool = false

    func reset() {
        presentationTimeStampBase = nil
        previousDecodeTimeStamp = nil
    }

    func hasReference() -> Bool {
        presentationTimeStampBase != nil
    }

    func setReference(now: Double, presentationTimeStamp: Double) {
        presentationTimeStampBase = now - presentationTimeStamp
        logger.info("""
        timecode: Updated base time - NTP: \(now) PTS: \(presentationTimeStamp) \
        BASE: \(presentationTimeStampBase!)
        """)
    }

    func makeTimecode(_ presentationTimeStamp: CMTime, _ decodeTimeStamp: CMTime) -> MpegTsTimecode? {
        guard let presentationTimeStampBase else {
            return nil
        }
        let presentationTimeStamp = presentationTimeStamp.seconds
        var decodeTimeStamp = decodeTimeStamp.seconds
        if decodeTimeStamp.isNaN {
            decodeTimeStamp = presentationTimeStamp
        }
        if let previousDecodeTimeStamp {
            estimatedFrameDuration = 0.7 * estimatedFrameDuration + 0.3 *
                (decodeTimeStamp - previousDecodeTimeStamp)
        }
        previousDecodeTimeStamp = decodeTimeStamp
        let now = Date(timeIntervalSince1970: presentationTimeStampBase
            + presentationTimeStamp
            + (offsetingFrames ? estimatedFrameDuration / 2 : 0))
        let offsetWithinSecond = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        let frame = offsetWithinSecond / estimatedFrameDuration
        let offsetFromFrame = offsetWithinSecond - frame.rounded(.down) * estimatedFrameDuration
        if offsetFromFrame < estimatedFrameDuration / 6 || offsetFromFrame > estimatedFrameDuration * 5 / 6 {
            offsetingFrames.toggle()
        }
        return MpegTsTimecode(clock: now, frame: UInt32(frame))
    }
}
