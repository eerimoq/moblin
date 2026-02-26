import AVFoundation
import SwiftUI

enum SettingsLogLevel: String, Codable, CaseIterable {
    case error = "Error"
    case info = "Info"
    case debug = "Debug"
}

let pixelFormats = ["32BGRA", "420YpCbCr8BiPlanarFullRange", "420YpCbCr8BiPlanarVideoRange"]
let pixelFormatTypes = [
    kCVPixelFormatType_32BGRA,
    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
]

class SettingsDebug: Codable, ObservableObject {
    static let builtinAudioAndVideoDelayDefault: Double = 0.07
    var logLevel: SettingsLogLevel = .error
    @Published var logFilter: String = ""
    @Published var debugLogging: Bool = false
    var debugLoggingMigrated: Bool = false
    @Published var debugOverlay: Bool = false
    var srtOverheadBandwidth: Int32 = 25
    @Published var cameraSwitchRemoveBlackish: Float = 0.3
    var maximumBandwidthFollowInput: Bool = true
    @Published var bluetoothOutputOnly: Bool = true
    var maximumLogLines: Int = 500
    var pixelFormat: String = pixelFormats[1]
    // To be removed.
    var faceToBeRemoved: SettingsFace = .init()
    @Published var allowVideoRangePixelFormat: Bool = false
    var blurSceneSwitch: Bool = true
    @Published var preferStereoMic: Bool = false
    @Published var twitchRewards: Bool = false
    var tesla: SettingsTesla = .init()
    var dnsLookupStrategy: SettingsDnsLookupStrategy = .system
    @Published var dataRateLimitFactor: Float = 2.0
    @Published var bitrateDropFix: Bool = false
    @Published var relaxedBitrate: Bool = false
    var externalDisplayChat: Bool = false
    var videoSourceWidgetTrackFace: Bool = false
    var replay: Bool = false
    var recordSegmentLength: Double = 5.0
    @Published var builtinAudioAndVideoDelay: Double = builtinAudioAndVideoDelayDefault
    var builtinAudioAndVideoDelay70msMigrated: Bool = false
    @Published var cameraManMoveVertically: Bool = false
    @Published var cameraManSpeed: Double = 1.0

    enum CodingKeys: CodingKey {
        case logLevel,
             logFilter,
             debugLogging,
             debugLoggingMigrated,
             srtOverlay,
             srtOverheadBandwidth,
             cameraSwitchRemoveBlackish,
             maximumBandwidthFollowInput,
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
             builtinAudioAndVideoDelay70msMigrated,
             cameraManMoveVertically,
             cameraManSpeed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.logLevel, logLevel)
        try container.encode(.logFilter, logFilter)
        try container.encode(.debugLogging, debugLogging)
        try container.encode(.debugLoggingMigrated, debugLoggingMigrated)
        try container.encode(.srtOverlay, debugOverlay)
        try container.encode(.srtOverheadBandwidth, srtOverheadBandwidth)
        try container.encode(.cameraSwitchRemoveBlackish, cameraSwitchRemoveBlackish)
        try container.encode(.maximumBandwidthFollowInput, maximumBandwidthFollowInput)
        try container.encode(.bluetoothOutputOnly, bluetoothOutputOnly)
        try container.encode(.maximumLogLines, maximumLogLines)
        try container.encode(.pixelFormat, pixelFormat)
        try container.encode(.beautyFilterSettings, faceToBeRemoved)
        try container.encode(.allowVideoRangePixelFormat, allowVideoRangePixelFormat)
        try container.encode(.blurSceneSwitch, blurSceneSwitch)
        try container.encode(.preferStereoMic, preferStereoMic)
        try container.encode(.twitchRewards, twitchRewards)
        try container.encode(.tesla, tesla)
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
        try container.encode(.dataRateLimitFactor, dataRateLimitFactor)
        try container.encode(.bitrateDropFix, bitrateDropFix)
        try container.encode(.relaxedBitrate, relaxedBitrate)
        try container.encode(.externalDisplayChat, externalDisplayChat)
        try container.encode(.videoSourceWidgetTrackFace, videoSourceWidgetTrackFace)
        try container.encode(.replay, replay)
        try container.encode(.recordSegmentLength, recordSegmentLength)
        try container.encode(.builtinAudioAndVideoDelay, builtinAudioAndVideoDelay)
        try container.encode(.builtinAudioAndVideoDelay70msMigrated, builtinAudioAndVideoDelay70msMigrated)
        try container.encode(.cameraManMoveVertically, cameraManMoveVertically)
        try container.encode(.cameraManSpeed, cameraManSpeed)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logLevel = container.decode(.logLevel, SettingsLogLevel.self, .error)
        logFilter = container.decode(.logFilter, String.self, "")
        debugLogging = container.decode(.debugLogging, Bool.self, false)
        debugLoggingMigrated = container.decode(.debugLoggingMigrated, Bool.self, false)
        if !debugLoggingMigrated {
            debugLogging = logLevel == .debug
            debugLoggingMigrated = true
        }
        debugOverlay = container.decode(.srtOverlay, Bool.self, false)
        srtOverheadBandwidth = container.decode(.srtOverheadBandwidth, Int32.self, 25)
        cameraSwitchRemoveBlackish = container.decode(.cameraSwitchRemoveBlackish, Float.self, 0.3)
        maximumBandwidthFollowInput = container.decode(.maximumBandwidthFollowInput, Bool.self, true)
        bluetoothOutputOnly = container.decode(.bluetoothOutputOnly, Bool.self, true)
        maximumLogLines = container.decode(.maximumLogLines, Int.self, 500)
        pixelFormat = container.decode(.pixelFormat, String.self, pixelFormats[1])
        faceToBeRemoved = container.decode(.beautyFilterSettings, SettingsFace.self, .init())
        allowVideoRangePixelFormat = container.decode(.allowVideoRangePixelFormat, Bool.self, false)
        blurSceneSwitch = container.decode(.blurSceneSwitch, Bool.self, true)
        preferStereoMic = container.decode(.preferStereoMic, Bool.self, false)
        twitchRewards = container.decode(.twitchRewards, Bool.self, false)
        tesla = container.decode(.tesla, SettingsTesla.self, .init())
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
        builtinAudioAndVideoDelay70msMigrated = container.decode(.builtinAudioAndVideoDelay70msMigrated,
                                                                 Bool.self,
                                                                 false)
        if !builtinAudioAndVideoDelay70msMigrated, builtinAudioAndVideoDelay == 0 {
            builtinAudioAndVideoDelay = Self.builtinAudioAndVideoDelayDefault
        }
        builtinAudioAndVideoDelay70msMigrated = true
        cameraManMoveVertically = container.decode(.cameraManMoveVertically, Bool.self, false)
        cameraManSpeed = container.decode(.cameraManSpeed, Double.self, 1.0)
    }
}
