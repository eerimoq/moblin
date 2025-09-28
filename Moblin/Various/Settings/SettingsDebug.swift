import AVFoundation

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

class SettingsDebugBeautyFilter: Codable, ObservableObject {
    @Published var showBlur = false
    @Published var showBlurBackground: Bool = false
    @Published var showMoblin = false
    @Published var showCute: Bool = false
    var cuteRadius: Float = 0.5
    var cuteScale: Float = 0.0
    var cuteOffset: Float = 0.5
    var showBeauty: Bool = false
    var shapeRadius: Float = 0.5
    var shapeScale: Float = 0.0
    var shapeOffset: Float = 0.5
    var smoothAmount: Float = 0.65
    var smoothRadius: Float = 20.0

    enum CodingKeys: CodingKey {
        case showBlur,
             showBlurBackground,
             showMoblin,
             showCute,
             cuteRadius,
             cuteScale,
             cuteOffset,
             showBeauty,
             shapeRadius,
             shapeScale,
             shapeOffset,
             smoothAmount,
             smoothRadius
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.showBlur, showBlur)
        try container.encode(.showBlurBackground, showBlurBackground)
        try container.encode(.showMoblin, showMoblin)
        try container.encode(.showCute, showCute)
        try container.encode(.cuteRadius, cuteRadius)
        try container.encode(.cuteScale, cuteScale)
        try container.encode(.cuteOffset, cuteOffset)
        try container.encode(.showBeauty, showBeauty)
        try container.encode(.shapeRadius, shapeRadius)
        try container.encode(.shapeScale, shapeScale)
        try container.encode(.shapeOffset, shapeOffset)
        try container.encode(.smoothAmount, smoothAmount)
        try container.encode(.smoothRadius, smoothRadius)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showBlur = container.decode(.showBlur, Bool.self, false)
        showBlurBackground = container.decode(.showBlurBackground, Bool.self, false)
        showMoblin = container.decode(.showMoblin, Bool.self, false)
        showCute = container.decode(.showCute, Bool.self, false)
        cuteRadius = container.decode(.cuteRadius, Float.self, 0.5)
        cuteScale = container.decode(.cuteScale, Float.self, 0.0)
        cuteOffset = container.decode(.cuteOffset, Float.self, 0.5)
        showBeauty = container.decode(.showBeauty, Bool.self, false)
        shapeRadius = container.decode(.shapeRadius, Float.self, 0.5)
        shapeScale = container.decode(.shapeScale, Float.self, 0.0)
        shapeOffset = container.decode(.shapeOffset, Float.self, 0.5)
        smoothAmount = container.decode(.smoothAmount, Float.self, 0.65)
        smoothRadius = container.decode(.smoothRadius, Float.self, 20.0)
    }
}

class SettingsHttpProxy: Codable {
    var enabled: Bool = false
    var host: String = ""
    var port: UInt16 = 3128

    func toHttpProxy() -> HttpProxy? {
        if enabled {
            return .init(host: host, port: port)
        } else {
            return nil
        }
    }
}

class SettingsDebug: Codable, ObservableObject {
    var logLevel: SettingsLogLevel = .error
    @Published var debugOverlay: Bool = false
    var srtOverheadBandwidth: Int32 = 25
    @Published var cameraSwitchRemoveBlackish: Float = 0.3
    var maximumBandwidthFollowInput: Bool = true
    var audioOutputToInputChannelsMap: SettingsDebugAudioOutputToInputChannelsMap = .init()
    @Published var bluetoothOutputOnly: Bool = true
    var maximumLogLines: Int = 500
    var pixelFormat: String = pixelFormats[1]
    @Published var beautyFilter: Bool = false
    var beautyFilterSettings: SettingsDebugBeautyFilter = .init()
    @Published var allowVideoRangePixelFormat: Bool = false
    var blurSceneSwitch: Bool = true
    @Published var metalPetalFilters: Bool = false
    @Published var preferStereoMic: Bool = false
    @Published var twitchRewards: Bool = false
    @Published var removeWindNoise: Bool = false
    var httpProxy: SettingsHttpProxy = .init()
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
    @Published var builtinAudioAndVideoDelay: Double = 0.0
    @Published var newSrt: Bool = false

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
             beautyFilter,
             beautyFilterSettings,
             allowVideoRangePixelFormat,
             blurSceneSwitch,
             metalPetalFilters,
             preferStereoMic,
             twitchRewards,
             removeWindNoise,
             httpProxy,
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
             newSrt
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
        try container.encode(.beautyFilter, beautyFilter)
        try container.encode(.beautyFilterSettings, beautyFilterSettings)
        try container.encode(.allowVideoRangePixelFormat, allowVideoRangePixelFormat)
        try container.encode(.blurSceneSwitch, blurSceneSwitch)
        try container.encode(.metalPetalFilters, metalPetalFilters)
        try container.encode(.preferStereoMic, preferStereoMic)
        try container.encode(.twitchRewards, twitchRewards)
        try container.encode(.removeWindNoise, removeWindNoise)
        try container.encode(.httpProxy, httpProxy)
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
        beautyFilter = container.decode(.beautyFilter, Bool.self, false)
        beautyFilterSettings = container.decode(.beautyFilterSettings, SettingsDebugBeautyFilter.self, .init())
        allowVideoRangePixelFormat = container.decode(.allowVideoRangePixelFormat, Bool.self, false)
        blurSceneSwitch = container.decode(.blurSceneSwitch, Bool.self, true)
        metalPetalFilters = container.decode(.metalPetalFilters, Bool.self, false)
        preferStereoMic = container.decode(.preferStereoMic, Bool.self, false)
        twitchRewards = container.decode(.twitchRewards, Bool.self, false)
        removeWindNoise = container.decode(.removeWindNoise, Bool.self, false)
        httpProxy = container.decode(.httpProxy, SettingsHttpProxy.self, .init())
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
        builtinAudioAndVideoDelay = container.decode(.builtinAudioAndVideoDelay, Double.self, 0.0)
        newSrt = container.decode(.newSrt, Bool.self, false)
    }
}
