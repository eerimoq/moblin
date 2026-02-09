import AVFAudio
import CoreMedia
import Foundation
import HaishinKit
import libdatachannel

public protocol RTCStreamTrack: Sendable {
    var id: String { get }
}

public struct AudioStreamTrack: RTCStreamTrack, Sendable {
    public let id: String
    public let settings: AudioCodecSettings

    public init(_ settings: AudioCodecSettings) {
        self.id = UUID().uuidString
        self.settings = settings
    }
}

public struct VideoStreamTrack: RTCStreamTrack, Sendable {
    public let id: String
    public let settings: VideoCodecSettings

    public init(_ settings: VideoCodecSettings) {
        self.id = UUID().uuidString
        self.settings = settings
    }
}
