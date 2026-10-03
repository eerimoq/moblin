import AVFoundation
import SwiftUI

enum SettingsLogLevel: String, Codable, CaseIterable {
    case error = "Error"
    case info = "Info"
    case debug = "Debug"
}

class SettingsDebug: Codable, ObservableObject {
    static let builtinAudioAndVideoDelayDefault: Double = 0.07
    var logLevel: SettingsLogLevel = .error
    @Published var logFilter: String = ""
    @Published var debugLogging: Bool = false
    var debugLoggingMigrated: Bool = false
    @Published var debugOverlay: Bool = false
    @Published var cameraSwitchRemoveBlackish: Float = 0.3
    @Published var bluetoothOutputOnly: Bool = true
    var maximumLogLines: Int = 500
    @Published var nativeLowLightBoost: Bool = false
    var blurSceneSwitch: Bool = true
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
    @Published var cameraManAlwaysMove: Bool = false
    @Published var enhancedMoblinSrt: Bool = false
    @Published var videoBitrateChange: Bool = false
    var highQualityDownsamplingToBeRemoved: Bool = false
    var httpProxyToBeRemoved: Bool = false
    @Published var packetPadding: Bool = false
    @Published var externalCameraVideoRange: Bool = false

    enum CodingKeys: CodingKey {
        case logLevel
        case logFilter
        case debugLogging
        case debugLoggingMigrated
        case srtOverlay
        case cameraSwitchRemoveBlackish
        case bluetoothOutputOnly
        case maximumLogLines
        case nativeLowLightBoost
        case blurSceneSwitch
        case twitchRewards
        case removeWindNoise
        case tesla
        case reliableChat
        case timecodesEnabled
        case dnsLookupStrategy
        case srtlaBatchSend
        case dataRateLimitFactor
        case bitrateDropFix
        case relaxedBitrate
        case externalDisplayChat
        case videoSourceWidgetTrackFace
        case srtlaBatchSendEnabled
        case replay
        case recordSegmentLength
        case builtinAudioAndVideoDelay
        case overrideSceneMic
        case autoLowPowerMode
        case builtinAudioAndVideoDelay70msMigrated
        case cameraManMoveVertically
        case cameraManSpeed
        case cameraManAlwaysMove
        case enhancedMoblinSrt
        case videoBitrateChangeEnabled
        case highQualityDownsampling
        case httpProxy3
        case packetPadding
        case externalCameraVideoRange
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.logLevel, logLevel)
        try container.encode(.logFilter, logFilter)
        try container.encode(.debugLogging, debugLogging)
        try container.encode(.debugLoggingMigrated, debugLoggingMigrated)
        try container.encode(.srtOverlay, debugOverlay)
        try container.encode(.cameraSwitchRemoveBlackish, cameraSwitchRemoveBlackish)
        try container.encode(.bluetoothOutputOnly, bluetoothOutputOnly)
        try container.encode(.maximumLogLines, maximumLogLines)
        try container.encode(.nativeLowLightBoost, nativeLowLightBoost)
        try container.encode(.blurSceneSwitch, blurSceneSwitch)
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
        try container.encode(.cameraManAlwaysMove, cameraManAlwaysMove)
        try container.encode(.enhancedMoblinSrt, enhancedMoblinSrt)
        try container.encode(.videoBitrateChangeEnabled, videoBitrateChange)
        try container.encode(.highQualityDownsampling, highQualityDownsamplingToBeRemoved)
        try container.encode(.httpProxy3, httpProxyToBeRemoved)
        try container.encode(.packetPadding, packetPadding)
        try container.encode(.externalCameraVideoRange, externalCameraVideoRange)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
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
        cameraSwitchRemoveBlackish = container.decode(.cameraSwitchRemoveBlackish, Float.self, 0.3)
        bluetoothOutputOnly = container.decode(.bluetoothOutputOnly, Bool.self, true)
        maximumLogLines = container.decode(.maximumLogLines, Int.self, 500)
        nativeLowLightBoost = container.decode(.nativeLowLightBoost, Bool.self, false)
        blurSceneSwitch = container.decode(.blurSceneSwitch, Bool.self, true)
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
        cameraManAlwaysMove = container.decode(.cameraManAlwaysMove, Bool.self, false)
        enhancedMoblinSrt = container.decode(.enhancedMoblinSrt, Bool.self, false)
        videoBitrateChange = container.decode(.videoBitrateChangeEnabled, Bool.self, false)
        highQualityDownsamplingToBeRemoved = container.decode(.highQualityDownsampling, Bool.self, false)
        httpProxyToBeRemoved = container.decode(.httpProxy3, Bool.self, false)
        packetPadding = container.decode(.packetPadding, Bool.self, false)
        externalCameraVideoRange = container.decode(.externalCameraVideoRange, Bool.self, false)
    }
}
