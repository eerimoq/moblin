import AVFoundation
import SwiftUI

enum SettingsLogLevel: String, Codable, CaseIterable {
    case error = "Error"
    case info = "Info"
    case debug = "Debug"

    init(from decoder: Decoder) throws {
        self = try SettingsLogLevel(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .error
    }
}

class SettingsDebugAudioOutputToInputChannelsMap: Codable {
    var channel0: Int = 0
    var channel1: Int = 1
}

let pixelFormats = ["32BGRA", "420YpCbCr8BiPlanarFullRange", "420YpCbCr8BiPlanarVideoRange"]
let pixelFormatTypes = [
    kCVPixelFormatType_32BGRA,
    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
]

enum SettingsFacePrivacyMode: String, Codable, CaseIterable {
    case blur
    case pixellate

    init(from decoder: Decoder) throws {
        self = try SettingsFacePrivacyMode(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .blur
    }

    func toString() -> LocalizedStringKey {
        switch self {
        case .blur:
            return "Blur"
        case .pixellate:
            return "Pixellate"
        }
    }
}

class SettingsFace: Codable, ObservableObject {
    @Published var showBlur = false
    @Published var showBlurBackground: Bool = false
    @Published var showMoblin = false
    @Published var privacyMode: SettingsFacePrivacyMode = .blur
    @Published var blurStrength: Float = 1.0
    @Published var pixellateStrength: Float = 0.3

    enum CodingKeys: CodingKey {
        case showBlur,
             showBlurBackground,
             showMoblin,
             privacyMode,
             blurStrength,
             pixellateStrength
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.showBlur, showBlur)
        try container.encode(.showBlurBackground, showBlurBackground)
        try container.encode(.showMoblin, showMoblin)
        try container.encode(.privacyMode, privacyMode)
        try container.encode(.blurStrength, blurStrength)
        try container.encode(.pixellateStrength, pixellateStrength)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showBlur = container.decode(.showBlur, Bool.self, false)
        showBlurBackground = container.decode(.showBlurBackground, Bool.self, false)
        showMoblin = container.decode(.showMoblin, Bool.self, false)
        privacyMode = container.decode(.privacyMode, SettingsFacePrivacyMode.self, .blur)
        blurStrength = container.decode(.blurStrength, Float.self, 1.0)
        pixellateStrength = container.decode(.pixellateStrength, Float.self, 0.3)
    }

    func toEffectSettings() -> FaceEffectSettings {
        let faceEffectPrivacyMode: FaceEffectPrivacyMode
        switch privacyMode {
        case .blur:
            faceEffectPrivacyMode = .blur(strength: blurStrength)
        case .pixellate:
            faceEffectPrivacyMode = .pixellate(strength: pixellateStrength)
        }
        return FaceEffectSettings(showBlur: showBlur,
                                  showBlurBackground: showBlurBackground,
                                  showMouth: showMoblin,
                                  privacyMode: faceEffectPrivacyMode)
    }
}

class SettingsDebug: Codable, ObservableObject {
    static let builtinAudioAndVideoDelayDefault: Double = 0.07
    var logLevel: SettingsLogLevel = .error
    @Published var debugOverlay: Bool = false
    var srtOverheadBandwidth: Int32 = 25
    @Published var cameraSwitchRemoveBlackish: Float = 0.3
    var maximumBandwidthFollowInput: Bool = true
    var audioOutputToInputChannelsMap: SettingsDebugAudioOutputToInputChannelsMap = .init()
    @Published var bluetoothOutputOnly: Bool = true
    var maximumLogLines: Int = 500
    var pixelFormat: String = pixelFormats[1]
    var face: SettingsFace = .init()
    @Published var allowVideoRangePixelFormat: Bool = false
    var blurSceneSwitch: Bool = true
    @Published var preferStereoMic: Bool = false
    @Published var twitchRewards: Bool = false
    var tesla: SettingsTesla = .init()
    @Published var reliableChat: Bool = false
    var dnsLookupStrategy: SettingsDnsLookupStrategy = .system
    @Published var dataRateLimitFactor: Float = 2.0
    @Published var bitrateDropFix: Bool = false
    @Published var relaxedBitrate: Bool = false
    var externalDisplayChat: Bool = false
    var videoSourceWidgetTrackFace: Bool = false
    var replay: Bool = false
    var recordSegmentLength: Double = 5.0
    @Published var builtinAudioAndVideoDelay: Double = builtinAudioAndVideoDelayDefault
    @Published var newSrt: Bool = false
    var builtinAudioAndVideoDelay70msMigrated: Bool = false

    enum CodingKeys: CodingKey {
        case logLevel,
             srtOverlay,
             srtOverheadBandwidth,
             cameraSwitchRemoveBlackish,
             maximumBandwidthFollowInput,
             audioOutputToInputChannelsMap,
             bluetoothOutputOnly,
             maximumLogLines,
             pixelFormat,
             beautyFilterSettings,
             allowVideoRangePixelFormat,
             blurSceneSwitch,
             preferStereoMic,
             twitchRewards,
             removeWindNoise,
             tesla,
             reliableChat,
             timecodesEnabled,
             dnsLookupStrategy,
             srtlaBatchSend,
             dataRateLimitFactor,
             bitrateDropFix,
             relaxedBitrate,
             externalDisplayChat,
             videoSourceWidgetTrackFace,
             srtlaBatchSendEnabled,
             replay,
             recordSegmentLength,
             builtinAudioAndVideoDelay,
             overrideSceneMic,
             autoLowPowerMode,
             newSrt,
             builtinAudioAndVideoDelay70msMigrated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.logLevel, logLevel)
        try container.encode(.srtOverlay, debugOverlay)
        try container.encode(.srtOverheadBandwidth, srtOverheadBandwidth)
        try container.encode(.cameraSwitchRemoveBlackish, cameraSwitchRemoveBlackish)
        try container.encode(.maximumBandwidthFollowInput, maximumBandwidthFollowInput)
        try container.encode(.audioOutputToInputChannelsMap, audioOutputToInputChannelsMap)
        try container.encode(.bluetoothOutputOnly, bluetoothOutputOnly)
        try container.encode(.maximumLogLines, maximumLogLines)
        try container.encode(.pixelFormat, pixelFormat)
        try container.encode(.beautyFilterSettings, face)
        try container.encode(.allowVideoRangePixelFormat, allowVideoRangePixelFormat)
        try container.encode(.blurSceneSwitch, blurSceneSwitch)
        try container.encode(.preferStereoMic, preferStereoMic)
        try container.encode(.twitchRewards, twitchRewards)
        try container.encode(.tesla, tesla)
        try container.encode(.reliableChat, reliableChat)
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
        try container.encode(.dataRateLimitFactor, dataRateLimitFactor)
        try container.encode(.bitrateDropFix, bitrateDropFix)
        try container.encode(.relaxedBitrate, relaxedBitrate)
        try container.encode(.externalDisplayChat, externalDisplayChat)
        try container.encode(.videoSourceWidgetTrackFace, videoSourceWidgetTrackFace)
        try container.encode(.replay, replay)
        try container.encode(.recordSegmentLength, recordSegmentLength)
        try container.encode(.builtinAudioAndVideoDelay, builtinAudioAndVideoDelay)
        try container.encode(.newSrt, newSrt)
        try container.encode(.builtinAudioAndVideoDelay70msMigrated, builtinAudioAndVideoDelay70msMigrated)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logLevel = container.decode(.logLevel, SettingsLogLevel.self, .error)
        debugOverlay = container.decode(.srtOverlay, Bool.self, false)
        srtOverheadBandwidth = container.decode(.srtOverheadBandwidth, Int32.self, 25)
        cameraSwitchRemoveBlackish = container.decode(.cameraSwitchRemoveBlackish, Float.self, 0.3)
        maximumBandwidthFollowInput = container.decode(.maximumBandwidthFollowInput, Bool.self, true)
        audioOutputToInputChannelsMap = container.decode(.audioOutputToInputChannelsMap,
                                                         SettingsDebugAudioOutputToInputChannelsMap.self,
                                                         .init())
        bluetoothOutputOnly = container.decode(.bluetoothOutputOnly, Bool.self, true)
        maximumLogLines = container.decode(.maximumLogLines, Int.self, 500)
        pixelFormat = container.decode(.pixelFormat, String.self, pixelFormats[1])
        face = container.decode(.beautyFilterSettings, SettingsFace.self, .init())
        allowVideoRangePixelFormat = container.decode(.allowVideoRangePixelFormat, Bool.self, false)
        blurSceneSwitch = container.decode(.blurSceneSwitch, Bool.self, true)
        preferStereoMic = container.decode(.preferStereoMic, Bool.self, false)
        twitchRewards = container.decode(.twitchRewards, Bool.self, false)
        tesla = container.decode(.tesla, SettingsTesla.self, .init())
        reliableChat = container.decode(.reliableChat, Bool.self, false)
        dnsLookupStrategy = container.decode(.dnsLookupStrategy, SettingsDnsLookupStrategy.self, .system)
        dataRateLimitFactor = container.decode(.dataRateLimitFactor, Float.self, 2.0)
        bitrateDropFix = container.decode(.bitrateDropFix, Bool.self, false)
        relaxedBitrate = container.decode(.relaxedBitrate, Bool.self, false)
        externalDisplayChat = container.decode(.externalDisplayChat, Bool.self, false)
        videoSourceWidgetTrackFace = container.decode(.videoSourceWidgetTrackFace, Bool.self, false)
        replay = container.decode(.replay, Bool.self, false)
        recordSegmentLength = container.decode(.recordSegmentLength, Double.self, 5.0)
        builtinAudioAndVideoDelay = container.decode(.builtinAudioAndVideoDelay,
                                                     Double.self,
                                                     Self.builtinAudioAndVideoDelayDefault)
        newSrt = container.decode(.newSrt, Bool.self, false)
        builtinAudioAndVideoDelay70msMigrated = container.decode(.builtinAudioAndVideoDelay70msMigrated,
                                                                 Bool.self,
                                                                 false)
        if !builtinAudioAndVideoDelay70msMigrated, builtinAudioAndVideoDelay == 0 {
            builtinAudioAndVideoDelay = Self.builtinAudioAndVideoDelayDefault
        }
        builtinAudioAndVideoDelay70msMigrated = true
    }
}
