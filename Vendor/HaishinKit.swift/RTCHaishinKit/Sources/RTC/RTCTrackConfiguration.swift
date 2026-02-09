import Foundation
import HaishinKit
import libdatachannel

struct RTCTrackConfiguration: Sendable {
    private static func generateSSRC() -> UInt32 {
        var ssrc: UInt32 = 0
        repeat {
            ssrc = UInt32.random(in: 1...UInt32.max)
        } while ssrc == 0
        return ssrc
    }

    private static func generateCName() -> String {
        return String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))
    }

    let codec: rtcCodec
    let ssrc: UInt32
    let pt: Int32
    let mid: String
    let name: String
    let msid: String
    let trackId: String
    let profile: String?
}

extension RTCTrackConfiguration {
    init(mid: String, streamId: String, audioCodecSettings: AudioCodecSettings) {
        self.codec = audioCodecSettings.format.cValue ?? RTC_CODEC_OPUS
        self.ssrc = Self.generateSSRC()
        self.pt = 111
        self.mid = mid
        self.name = Self.generateCName()
        self.msid = streamId
        self.trackId = UUID().uuidString
        self.profile = "minptime=10;useinbandfec=1;stereo=1;sprop-stereo=1"
    }

    init(mid: String, streamId: String, videoCodecSettings: VideoCodecSettings) {
        self.codec = videoCodecSettings.format.cValue
        self.ssrc = Self.generateSSRC()
        self.pt = 98
        self.mid = mid
        self.name = Self.generateCName()
        self.msid = streamId
        self.trackId = UUID().uuidString
        self.profile = nil
    }
}

extension RTCTrackConfiguration {
    func addTrack(_ connection: Int32, direction: RTCDirection) throws -> Int32 {
        var rtcTrackInit = makeRtcTrackInit(direction)
        let result = try RTCError.check(rtcAddTrackEx(connection, &rtcTrackInit))
        return result
    }

    private func makeRtcTrackInit(_ direction: RTCDirection) -> rtcTrackInit {
        // TODO: Fix memory leak
        return rtcTrackInit(
            direction: direction.cValue,
            codec: codec,
            payloadType: pt,
            ssrc: ssrc,
            mid: strdup(mid),
            name: strdup(name),
            msid: strdup(msid),
            trackId: strdup(trackId),
            profile: profile == nil ? nil : strdup(profile)
        )
    }
}
