import HaishinKit
import libdatachannel

extension AudioCodecSettings.Format {
    var cValue: rtcCodec? {
        switch self {
        case .opus:
            return RTC_CODEC_OPUS
        case .aac:
            return RTC_CODEC_AAC
        case .pcm:
            return nil
        }
    }
}
