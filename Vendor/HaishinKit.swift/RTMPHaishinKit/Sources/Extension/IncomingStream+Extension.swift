import CoreMedia
import HaishinKit

extension IncomingStream {
    func append(_ message: RTMPVideoMessage, presentationTimeStamp: CMTime, formatDesciption: CMFormatDescription?) {
        guard let buffer = message.makeSampleBuffer(presentationTimeStamp, formatDesciption: formatDesciption) else {
            return
        }
        append(buffer)
    }
}
