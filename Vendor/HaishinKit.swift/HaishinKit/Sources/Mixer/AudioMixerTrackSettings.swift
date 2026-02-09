import AVFoundation

/// Constraints on the audio mixier track's settings.
public struct AudioMixerTrackSettings: Codable, Sendable {
    /// The default value.
    public static let `default` = AudioMixerTrackSettings()

    /// Specifies the volume for output.
    public var volume: Float

    /// Specifies the muted that indicates whether the audio output is muted.
    public var isMuted = false

    /// Specifies the mixes the channels or not. Currently, it supports input sources with 4, 5, 6, and 8 channels.
    public var downmix = true

    /// Specifies the map of the output to input channels.
    /// ## Example code:
    /// ```swift
    /// // If you want to use the 3rd and 4th channels from a 4-channel input source for a 2-channel output, you would specify it like this.
    /// channelMap = [2, 3]
    /// ```
    public var channelMap: [Int]?

    /// Creates a new instance.
    public init(volume: Float = 1.0, isMuted: Bool = false, downmix: Bool = true, channelMap: [Int]? = nil) {
        self.volume = volume
        self.isMuted = isMuted
        self.downmix = downmix
        self.channelMap = channelMap
    }

    func apply(_ converter: AVAudioConverter?, oldValue: AudioMixerTrackSettings) {
        guard let converter else {
            return
        }
        if downmix != oldValue.downmix {
            converter.downmix = downmix
        }
        if channelMap != oldValue.channelMap {
            if let channelMap = validatedChannelMap(converter) {
                converter.channelMap = channelMap.map { NSNumber(value: $0) }
            }
        }
    }

    func validatedChannelMap(_ converter: AVAudioConverter) -> [Int]? {
        guard let channelMap, channelMap.count == converter.outputFormat.channelCount else {
            return nil
        }
        for inputChannel in channelMap where converter.inputFormat.channelCount <= inputChannel {
            return nil
        }
        return channelMap
    }
}
