import AVFoundation

enum SettingsStreamCodec: String, Codable, CaseIterable {
    case h265hevc = "H.265/HEVC"
    case h264avc = "H.264/AVC"

    init(from decoder: Decoder) throws {
        self = try SettingsStreamCodec(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .h264avc
    }

    func shortString() -> String {
        switch self {
        case .h265hevc:
            return "H.265"
        case .h264avc:
            return "H.264"
        }
    }
}

let codecs = SettingsStreamCodec.allCases.map { $0.rawValue }

enum SettingsStreamH264Profile: String, Codable, CaseIterable {
    case baseline = "Baseline"
    case main = "Main"
    case high = "High"

    init(from decoder: Decoder) throws {
        self = try SettingsStreamH264Profile(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .main
    }
}

enum SettingsStreamResolution: String, Codable, CaseIterable {
    case r4032x3024 = "4032x3024"
    case r3840x2160 = "3840x2160"
    case r2560x1440 = "2560x1440"
    case r1920x1440 = "1920x1440"
    case r1920x1080 = "1920x1080"
    case r1280x720 = "1280x720"
    case r1024x768 = "1024x768"
    case r960x540 = "960x540"
    case r854x480 = "854x480"
    case r640x360 = "640x360"
    case r426x240 = "426x240"

    init(from decoder: Decoder) throws {
        self = try SettingsStreamResolution(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .r1920x1080
    }

    static func > (lhs: SettingsStreamResolution, rhs: SettingsStreamResolution) -> Bool {
        return lhs.dimensions(portrait: false).width > rhs.dimensions(portrait: false).width
    }

    func shortString() -> String {
        switch self {
        case .r4032x3024:
            return "3024p (4:3)"
        case .r3840x2160:
            return "4K"
        case .r2560x1440:
            return "1440p"
        case .r1920x1440:
            return "1440p (4:3)"
        case .r1920x1080:
            return "1080p"
        case .r1024x768:
            return "768p (4:3)"
        case .r1280x720:
            return "720p"
        case .r960x540:
            return "540p"
        case .r854x480:
            return "480p"
        case .r640x360:
            return "360p"
        case .r426x240:
            return "240p"
        }
    }

    func dimensions(portrait: Bool) -> CMVideoDimensions {
        var size: CMVideoDimensions
        switch self {
        case .r4032x3024:
            size = .init(width: 4032, height: 3024)
        case .r3840x2160:
            size = .init(width: 3840, height: 2160)
        case .r2560x1440:
            size = .init(width: 2560, height: 1440)
        case .r1920x1440:
            size = .init(width: 1920, height: 1440)
        case .r1920x1080:
            size = .init(width: 1920, height: 1080)
        case .r1024x768:
            size = .init(width: 1024, height: 768)
        case .r1280x720:
            size = .init(width: 1280, height: 720)
        case .r960x540:
            size = .init(width: 960, height: 540)
        case .r854x480:
            size = .init(width: 854, height: 480)
        case .r640x360:
            size = .init(width: 640, height: 360)
        case .r426x240:
            size = .init(width: 426, height: 240)
        }
        if portrait {
            size = .init(width: size.height, height: size.width)
        }
        return size
    }
}

let resolutions = SettingsStreamResolution.allCases

let fpss = [120, 100, 60, 50, 30, 25, 15]

enum SettingsStreamAudioCodec: String, Codable, CaseIterable {
    case aac = "AAC"
    case opus = "OPUS"

    init(from decoder: Decoder) throws {
        self = try SettingsStreamAudioCodec(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .aac
    }

    func toEncoder() -> AudioEncoderSettings.Format {
        switch self {
        case .aac:
            return .aac
        case .opus:
            return .opus
        }
    }

    func toString() -> String {
        switch self {
        case .aac:
            return "AAC"
        case .opus:
            return "Opus"
        }
    }
}

enum SettingsStreamProtocol: String, Codable {
    case rtmp = "RTMP"
    case srt = "SRT"
    case rist = "RIST"

    init(from decoder: Decoder) throws {
        self = try SettingsStreamProtocol(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .rtmp
    }
}

enum SettingsStreamDetailedProtocol {
    case rtmp
    case rtmps
    case srt
    case srtla
    case rist
}

class SettingsStreamSrtConnectionPriority: Codable, Identifiable {
    var id: UUID = .init()
    var name: String
    var priority: Int = 1
    var enabled: Bool = true
    var relayId: UUID?

    init(name: String) {
        self.name = name
    }

    enum CodingKeys: CodingKey {
        case id,
             name,
             priority,
             enabled,
             relayId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.priority, priority)
        try container.encode(.enabled, enabled)
        try container.encode(.relayId, relayId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        priority = container.decode(.priority, Int.self, 1)
        enabled = container.decode(.enabled, Bool.self, true)
        relayId = container.decode(.relayId, UUID?.self, nil)
    }

    func clone() -> SettingsStreamSrtConnectionPriority {
        let new = SettingsStreamSrtConnectionPriority(name: name)
        new.priority = priority
        new.enabled = enabled
        new.relayId = relayId
        return new
    }
}

class SettingsStreamSrtConnectionPriorities: Codable {
    var enabled: Bool = false
    var priorities: [SettingsStreamSrtConnectionPriority] = [
        SettingsStreamSrtConnectionPriority(name: "Cellular"),
        SettingsStreamSrtConnectionPriority(name: "WiFi"),
    ]

    func clone() -> SettingsStreamSrtConnectionPriorities {
        let new = SettingsStreamSrtConnectionPriorities()
        new.enabled = enabled
        new.priorities.removeAll()
        for priority in priorities {
            new.priorities.append(priority.clone())
        }
        return new
    }
}

enum SettingsStreamSrtAdaptiveBitrateAlgorithm: Codable, CaseIterable {
    case belabox
    case fastIrl
    case slowIrl
    case customIrl

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(CodingKeys.belabox) {
            self = .belabox
        } else if container.contains(CodingKeys.fastIrl) {
            self = .fastIrl
        } else if container.contains(CodingKeys.slowIrl) {
            self = .slowIrl
        } else if container.contains(CodingKeys.customIrl) {
            self = .customIrl
        } else {
            self = .belabox
        }
    }

    func toString() -> String {
        switch self {
        case .belabox:
            return String(localized: "BELABOX")
        case .fastIrl:
            return String(localized: "Fast IRL")
        case .slowIrl:
            return String(localized: "Slow IRL")
        case .customIrl:
            return String(localized: "Custom IRL")
        }
    }
}

class SettingsStreamSrtAdaptiveBitrateFastIrlSettings: Codable {
    var packetsInFlight: Int32 = 200
    var minimumBitrate: Float = 250

    init() {}

    enum CodingKeys: CodingKey {
        case packetsInFlight,
             minimumBitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.packetsInFlight, packetsInFlight)
        try container.encode(.minimumBitrate, minimumBitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packetsInFlight = container.decode(.packetsInFlight, Int32.self, 200)
        minimumBitrate = container.decode(.minimumBitrate, Float.self, 250)
    }

    func clone() -> SettingsStreamSrtAdaptiveBitrateFastIrlSettings {
        let new = SettingsStreamSrtAdaptiveBitrateFastIrlSettings()
        new.packetsInFlight = packetsInFlight
        new.minimumBitrate = minimumBitrate
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrateCustomSettings: Codable {
    var packetsInFlight: Int32 = 200
    var pifDiffIncreaseFactor: Float = 100
    var rttDiffHighDecreaseFactor: Float = 0.9
    var rttDiffHighAllowedSpike: Float = 50
    var rttDiffHighMinimumDecrease: Float = 250
    var minimumBitrate: Float = 250

    init() {}

    enum CodingKeys: CodingKey {
        case packetsInFlight,
             pifDiffIncreaseFactor,
             rttDiffHighDecreaseFactor,
             rttDiffHighAllowedSpike,
             rttDiffHighMinimumDecrease,
             minimumBitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.packetsInFlight, packetsInFlight)
        try container.encode(.pifDiffIncreaseFactor, pifDiffIncreaseFactor)
        try container.encode(.rttDiffHighDecreaseFactor, rttDiffHighDecreaseFactor)
        try container.encode(.rttDiffHighAllowedSpike, rttDiffHighAllowedSpike)
        try container.encode(.rttDiffHighMinimumDecrease, rttDiffHighMinimumDecrease)
        try container.encode(.minimumBitrate, minimumBitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packetsInFlight = container.decode(.packetsInFlight, Int32.self, 200)
        pifDiffIncreaseFactor = container.decode(.pifDiffIncreaseFactor, Float.self, 100)
        rttDiffHighDecreaseFactor = container.decode(.rttDiffHighDecreaseFactor, Float.self, 0.9)
        rttDiffHighAllowedSpike = container.decode(.rttDiffHighAllowedSpike, Float.self, 50)
        rttDiffHighMinimumDecrease = container.decode(.rttDiffHighMinimumDecrease, Float.self, 250)
        minimumBitrate = container.decode(.minimumBitrate, Float.self, 250)
    }

    func clone() -> SettingsStreamSrtAdaptiveBitrateCustomSettings {
        let new = SettingsStreamSrtAdaptiveBitrateCustomSettings()
        new.packetsInFlight = packetsInFlight
        new.pifDiffIncreaseFactor = pifDiffIncreaseFactor
        new.rttDiffHighDecreaseFactor = rttDiffHighDecreaseFactor
        new.rttDiffHighAllowedSpike = rttDiffHighAllowedSpike
        new.rttDiffHighMinimumDecrease = rttDiffHighMinimumDecrease
        new.minimumBitrate = minimumBitrate
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrateBelaboxSettings: Codable {
    var minimumBitrate: Float = 250

    init() {}

    enum CodingKeys: CodingKey {
        case minimumBitrate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.minimumBitrate, minimumBitrate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimumBitrate = container.decode(.minimumBitrate, Float.self, 250)
    }

    func clone() -> SettingsStreamSrtAdaptiveBitrateBelaboxSettings {
        let new = SettingsStreamSrtAdaptiveBitrateBelaboxSettings()
        new.minimumBitrate = minimumBitrate
        return new
    }
}

class SettingsStreamSrtAdaptiveBitrate: Codable {
    var algorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm = .belabox
    var fastIrlSettings: SettingsStreamSrtAdaptiveBitrateFastIrlSettings = .init()
    var customSettings: SettingsStreamSrtAdaptiveBitrateCustomSettings = .init()
    var belaboxSettings: SettingsStreamSrtAdaptiveBitrateBelaboxSettings = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case algorithm,
             fastIrlSettings,
             customSettings,
             belaboxSettings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.algorithm, algorithm)
        try container.encode(.fastIrlSettings, fastIrlSettings)
        try container.encode(.customSettings, customSettings)
        try container.encode(.belaboxSettings, belaboxSettings)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        algorithm = container.decode(.algorithm, SettingsStreamSrtAdaptiveBitrateAlgorithm.self, .belabox)
        fastIrlSettings = container.decode(
            .fastIrlSettings,
            SettingsStreamSrtAdaptiveBitrateFastIrlSettings.self,
            .init()
        )
        customSettings = container.decode(.customSettings, SettingsStreamSrtAdaptiveBitrateCustomSettings.self, .init())
        belaboxSettings = container.decode(
            .belaboxSettings,
            SettingsStreamSrtAdaptiveBitrateBelaboxSettings.self,
            .init()
        )
    }

    func clone() -> SettingsStreamSrtAdaptiveBitrate {
        let new = SettingsStreamSrtAdaptiveBitrate()
        new.algorithm = algorithm
        new.fastIrlSettings = fastIrlSettings.clone()
        new.customSettings = customSettings.clone()
        new.belaboxSettings = belaboxSettings.clone()
        return new
    }
}

class SettingsStreamSrt: Codable {
    var latency: Int32 = defaultSrtLatency
    var maximumBandwidthFollowInput: Bool = true
    var overheadBandwidth: Int32 = 25
    var adaptiveBitrateEnabled: Bool = true
    var adaptiveBitrate: SettingsStreamSrtAdaptiveBitrate = .init()
    var connectionPriorities: SettingsStreamSrtConnectionPriorities = .init()
    var mpegtsPacketsPerPacket: Int = 7
    var dnsLookupStrategy: SettingsDnsLookupStrategy = .system

    init() {}

    enum CodingKeys: CodingKey {
        case latency,
             maximumBandwidthFollowInput,
             overheadBandwidth,
             adaptiveBitrateEnabled,
             adaptiveBitrate,
             connectionPriorities,
             mpegtsPacketsPerPacket,
             dnsLookupStrategy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.latency, latency)
        try container.encode(.maximumBandwidthFollowInput, maximumBandwidthFollowInput)
        try container.encode(.overheadBandwidth, overheadBandwidth)
        try container.encode(.adaptiveBitrateEnabled, adaptiveBitrateEnabled)
        try container.encode(.adaptiveBitrate, adaptiveBitrate)
        try container.encode(.connectionPriorities, connectionPriorities)
        try container.encode(.mpegtsPacketsPerPacket, mpegtsPacketsPerPacket)
        try container.encode(.dnsLookupStrategy, dnsLookupStrategy)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latency = container.decode(.latency, Int32.self, defaultSrtLatency)
        maximumBandwidthFollowInput = container.decode(.maximumBandwidthFollowInput, Bool.self, true)
        overheadBandwidth = container.decode(.overheadBandwidth, Int32.self, 25)
        adaptiveBitrateEnabled = container.decode(.adaptiveBitrateEnabled, Bool.self, true)
        adaptiveBitrate = container.decode(.adaptiveBitrate, SettingsStreamSrtAdaptiveBitrate.self, .init())
        connectionPriorities = container.decode(.connectionPriorities,
                                                SettingsStreamSrtConnectionPriorities.self,
                                                .init())
        mpegtsPacketsPerPacket = container.decode(.mpegtsPacketsPerPacket, Int.self, 7)
        dnsLookupStrategy = container.decode(.dnsLookupStrategy, SettingsDnsLookupStrategy.self, .system)
    }

    func clone() -> SettingsStreamSrt {
        let new = SettingsStreamSrt()
        new.latency = latency
        new.overheadBandwidth = overheadBandwidth
        new.maximumBandwidthFollowInput = maximumBandwidthFollowInput
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        new.adaptiveBitrate = adaptiveBitrate.clone()
        new.connectionPriorities = connectionPriorities.clone()
        new.mpegtsPacketsPerPacket = mpegtsPacketsPerPacket
        new.dnsLookupStrategy = dnsLookupStrategy
        return new
    }
}

class SettingsStreamRtmp: Codable {
    var adaptiveBitrateEnabled: Bool = false

    func clone() -> SettingsStreamRtmp {
        let new = SettingsStreamRtmp()
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        return new
    }
}

class SettingsStreamRist: Codable {
    var adaptiveBitrateEnabled: Bool = false
    var bonding: Bool = false

    func clone() -> SettingsStreamRist {
        let new = SettingsStreamRist()
        new.adaptiveBitrateEnabled = adaptiveBitrateEnabled
        new.bonding = bonding
        return new
    }
}

class SettingsStreamChat: Codable {
    var bttvEmotes: Bool = false
    var ffzEmotes: Bool = false
    var seventvEmotes: Bool = false

    func clone() -> SettingsStreamChat {
        let new = SettingsStreamChat()
        new.bttvEmotes = bttvEmotes
        new.ffzEmotes = ffzEmotes
        new.seventvEmotes = seventvEmotes
        return new
    }
}

class SettingsStreamRecording: Codable, ObservableObject {
    @Published var overrideStream: Bool = false
    @Published var resolution: SettingsStreamResolution = SettingsStream.defaultResolution
    @Published var fps: Int = SettingsStream.defaultFps
    @Published var videoCodec: SettingsStreamCodec = .h265hevc
    @Published var videoBitrate: UInt32 = 0
    @Published var maxKeyFrameInterval: Int32 = 0
    @Published var audioBitrate: UInt32 = 128_000
    @Published var autoStartRecording: Bool = false
    @Published var autoStopRecording: Bool = false
    @Published var cleanRecordings: Bool = false
    @Published var cleanSnapshots: Bool = false
    @Published var recordingPath: Data?

    init() {}

    enum CodingKeys: CodingKey {
        case overrideStream,
             resolution,
             fps,
             videoCodec,
             videoBitrate,
             maxKeyFrameInterval,
             audioBitrate,
             autoStartRecording,
             autoStopRecording,
             cleanRecordings,
             cleanSnapshots,
             recordingPath
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.overrideStream, overrideStream)
        try container.encode(.resolution, resolution)
        try container.encode(.fps, fps)
        try container.encode(.videoCodec, videoCodec)
        try container.encode(.videoBitrate, videoBitrate)
        try container.encode(.maxKeyFrameInterval, maxKeyFrameInterval)
        try container.encode(.audioBitrate, audioBitrate)
        try container.encode(.autoStartRecording, autoStartRecording)
        try container.encode(.autoStopRecording, autoStopRecording)
        try container.encode(.cleanRecordings, cleanRecordings)
        try container.encode(.cleanSnapshots, cleanSnapshots)
        try container.encode(.recordingPath, recordingPath)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overrideStream = container.decode(.overrideStream, Bool.self, false)
        resolution = container.decode(.resolution, SettingsStreamResolution.self, SettingsStream.defaultResolution)
        fps = container.decode(.fps, Int.self, SettingsStream.defaultFps)
        videoCodec = container.decode(.videoCodec, SettingsStreamCodec.self, .h265hevc)
        videoBitrate = container.decode(.videoBitrate, UInt32.self, 0)
        maxKeyFrameInterval = container.decode(.maxKeyFrameInterval, Int32.self, 0)
        audioBitrate = container.decode(.audioBitrate, UInt32.self, 128_000)
        autoStartRecording = container.decode(.autoStartRecording, Bool.self, false)
        autoStopRecording = container.decode(.autoStopRecording, Bool.self, false)
        cleanRecordings = container.decode(.cleanRecordings, Bool.self, false)
        cleanSnapshots = container.decode(.cleanSnapshots, Bool.self, false)
        recordingPath = container.decode(.recordingPath, Data?.self, nil)
    }

    func clone() -> SettingsStreamRecording {
        let new = SettingsStreamRecording()
        new.videoCodec = videoCodec
        new.videoBitrate = videoBitrate
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioBitrate = audioBitrate
        new.autoStartRecording = autoStartRecording
        new.autoStopRecording = autoStopRecording
        new.cleanRecordings = cleanRecordings
        new.cleanSnapshots = cleanSnapshots
        new.recordingPath = recordingPath
        return new
    }

    func videoBitrateString() -> String {
        if videoBitrate != 0 {
            return formatBytesPerSecond(speed: Int64(videoBitrate))
        } else {
            return String(localized: "Auto")
        }
    }

    func maxKeyFrameIntervalString() -> String {
        if maxKeyFrameInterval != 0 {
            return "\(maxKeyFrameInterval) s"
        } else {
            return String(localized: "Auto")
        }
    }

    func audioBitrateString() -> String {
        if audioBitrate != 0 {
            return formatBytesPerSecond(speed: Int64(audioBitrate))
        } else {
            return String(localized: "Auto")
        }
    }

    func isDefaultRecordingPath() -> Bool {
        return recordingPath == nil
    }
}

enum SettingsStreamReplayTransitionType: String, Codable, CaseIterable {
    case fade
    case stingers
    case none

    init(from decoder: Decoder) throws {
        self = try SettingsStreamReplayTransitionType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .fade
    }

    func toString() -> String {
        switch self {
        case .fade:
            return String(localized: "Fade")
        case .stingers:
            return String(localized: "Stingers")
        case .none:
            return String(localized: "None")
        }
    }
}

struct SettingsStreamReplayStinger: Codable {
    var id: UUID = .init()
    var name: String = ""
    var transitionPoint: Double = 0.5

    func makeFilename() -> String? {
        guard let fileExtension = URL(string: "file:///\(name)")?.pathExtension else {
            return nil
        }
        return "\(id).\(fileExtension)"
    }
}

class SettingsStreamReplay: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var transitionType: SettingsStreamReplayTransitionType = .fade
    @Published var inStinger: SettingsStreamReplayStinger = .init()
    @Published var outStinger: SettingsStreamReplayStinger = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case enabled,
             fade,
             transitionType,
             inStinger,
             outStinger
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.transitionType, transitionType)
        try container.encode(.inStinger, inStinger)
        try container.encode(.outStinger, outStinger)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        if let fade = try? container.decode(Bool.self, forKey: .fade) {
            if fade {
                transitionType = .fade
            } else {
                transitionType = .none
            }
        } else {
            transitionType = container.decode(.transitionType, SettingsStreamReplayTransitionType.self, .fade)
        }
        inStinger = container.decode(.inStinger, SettingsStreamReplayStinger.self, .init())
        outStinger = container.decode(.outStinger, SettingsStreamReplayStinger.self, .init())
    }

    func clone() -> SettingsStreamReplay {
        let new = SettingsStreamReplay()
        new.enabled = enabled
        new.transitionType = transitionType
        new.inStinger = inStinger
        new.outStinger = outStinger
        return new
    }
}

class SettingsStreamTwitchReward: Codable, Identifiable {
    var id: UUID = .init()
    // periphery:ignore
    var rewardId: String = ""
    var title: String = ""
    // periphery:ignore
    var alert: SettingsWidgetAlertsAlert = .init()
}

class SettingsStreamMultiStreamingDestination: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My destination")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var url: String = defaultRtmpStreamUrl
    @Published var enabled: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case name,
             url,
             enabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.url, url)
        try container.encode(.enabled, enabled)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, Self.baseName)
        url = container.decode(.url, String.self, defaultRtmpStreamUrl)
        enabled = container.decode(.enabled, Bool.self, false)
    }

    func clone() -> SettingsStreamMultiStreamingDestination {
        let new = SettingsStreamMultiStreamingDestination()
        new.name = name
        new.url = url
        new.enabled = enabled
        return new
    }
}

class SettingsStreamMultiStreaming: Codable, ObservableObject {
    @Published var destinations: [SettingsStreamMultiStreamingDestination] = []

    init() {}

    enum CodingKeys: CodingKey {
        case destinations
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.destinations, destinations)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        destinations = container.decode(.destinations, [SettingsStreamMultiStreamingDestination].self, [])
    }

    func clone() -> SettingsStreamMultiStreaming {
        let new = SettingsStreamMultiStreaming()
        for destination in destinations {
            new.destinations.append(destination.clone())
        }
        return new
    }
}

class SettingsTwitchAlerts: Codable, ObservableObject {
    @Published var follows: Bool = true
    @Published var subscriptions: Bool = true
    @Published var giftSubscriptions: Bool = true
    @Published var resubscriptions: Bool = true
    @Published var rewards: Bool = true
    @Published var raids: Bool = true
    @Published var cheers: Bool = true
    @Published var minimumCheerBits: Int = 0

    init() {}

    enum CodingKeys: CodingKey {
        case follows,
             subscriptions,
             giftSubscriptions,
             resubscriptions,
             rewards,
             raids,
             cheers,
             minimumCheerBits
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.follows, follows)
        try container.encode(.subscriptions, subscriptions)
        try container.encode(.giftSubscriptions, giftSubscriptions)
        try container.encode(.resubscriptions, resubscriptions)
        try container.encode(.rewards, rewards)
        try container.encode(.raids, raids)
        try container.encode(.cheers, cheers)
        try container.encode(.minimumCheerBits, minimumCheerBits)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        follows = container.decode(.follows, Bool.self, true)
        subscriptions = container.decode(.subscriptions, Bool.self, true)
        giftSubscriptions = container.decode(.giftSubscriptions, Bool.self, true)
        resubscriptions = container.decode(.resubscriptions, Bool.self, true)
        rewards = container.decode(.rewards, Bool.self, true)
        raids = container.decode(.raids, Bool.self, true)
        cheers = container.decode(.cheers, Bool.self, true)
        minimumCheerBits = container.decode(.minimumCheerBits, Int.self, 0)
    }

    func clone() -> SettingsTwitchAlerts {
        let new = SettingsTwitchAlerts()
        new.follows = follows
        new.subscriptions = subscriptions
        new.giftSubscriptions = giftSubscriptions
        new.resubscriptions = resubscriptions
        new.rewards = rewards
        new.raids = raids
        new.cheers = cheers
        new.minimumCheerBits = minimumCheerBits
        return new
    }

    func isBitsEnabled(amount: Int) -> Bool {
        return cheers && amount >= minimumCheerBits
    }
}

class SettingsKickAlerts: Codable, ObservableObject {
    @Published var subscriptions: Bool = true
    @Published var giftedSubscriptions: Bool = true
    @Published var rewards: Bool = true
    @Published var hosts: Bool = true
    @Published var bans: Bool = true
    @Published var kicks: Bool = true
    @Published var minimumKicks: Int = 0

    init() {}

    enum CodingKeys: CodingKey {
        case subscriptions,
             giftedSubscriptions,
             rewards,
             hosts,
             bans,
             kicks,
             minimumKicks
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.subscriptions, subscriptions)
        try container.encode(.giftedSubscriptions, giftedSubscriptions)
        try container.encode(.rewards, rewards)
        try container.encode(.hosts, hosts)
        try container.encode(.bans, bans)
        try container.encode(.kicks, kicks)
        try container.encode(.minimumKicks, minimumKicks)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subscriptions = container.decode(.subscriptions, Bool.self, true)
        giftedSubscriptions = container.decode(.giftedSubscriptions, Bool.self, true)
        rewards = container.decode(.rewards, Bool.self, true)
        hosts = container.decode(.hosts, Bool.self, true)
        bans = container.decode(.bans, Bool.self, true)
        kicks = container.decode(.kicks, Bool.self, true)
        minimumKicks = container.decode(.minimumKicks, Int.self, 0)
    }

    func clone() -> SettingsKickAlerts {
        let new = SettingsKickAlerts()
        new.subscriptions = subscriptions
        new.giftedSubscriptions = giftedSubscriptions
        new.rewards = rewards
        new.hosts = hosts
        new.bans = bans
        new.kicks = kicks
        new.minimumKicks = minimumKicks
        return new
    }

    func isKicksEnabled(amount: Int) -> Bool {
        return kicks && amount >= minimumKicks
    }
}

class SettingsStream: Codable, Identifiable, Equatable, ObservableObject, Named {
    static let defaultRealtimeIrlBaseUrl = "https://rtirl.com/api"
    static let defaultResolution: SettingsStreamResolution = .r1920x1080
    static let defaultFps: Int = 30
    @Published var name: String
    var id: UUID = .init()
    var enabled: Bool = false
    @Published var url: String = defaultStreamUrl
    @Published var twitchChannelName: String = ""
    var twitchChannelId: String = ""
    var twitchShowFollows: Bool?
    var twitchChatAlerts: SettingsTwitchAlerts = .init()
    var twitchToastAlerts: SettingsTwitchAlerts = .init()
    var twitchAccessToken: String = ""
    var twitchLoggedIn: Bool = false
    var twitchRewards: [SettingsStreamTwitchReward] = []
    @Published var twitchSendMessagesTo: Bool = true
    @Published var kickChannelName: String = ""
    @Published var kickChannelId: String?
    @Published var kickChatroomChannelId: String?
    @Published var kickSlug: String?
    var kickAccessToken: String = ""
    @Published var kickLoggedIn: Bool = false
    @Published var kickSendMessagesTo: Bool = true
    var kickChatAlerts: SettingsKickAlerts = .init()
    var kickToastAlerts: SettingsKickAlerts = .init()
    @Published var dLiveUsername: String = ""
    var youTubeApiKey: String = ""
    @Published var youTubeVideoId: String = ""
    @Published var youTubeHandle: String = ""
    @Published var soopChannelName: String = ""
    var soopStreamId: String = ""
    var openStreamingPlatformUrl: String = ""
    var openStreamingPlatformChannelId: String = ""
    @Published var obsWebSocketEnabled: Bool = false
    var obsWebSocketUrl: String = ""
    var obsWebSocketPassword: String = ""
    @Published var obsSourceName: String = ""
    var obsMainScene: String = ""
    var obsBrbScene: String = ""
    var obsBrbSceneVideoSourceBroken: Bool = false
    var obsAutoStartStream: Bool = false
    var obsAutoStopStream: Bool = false
    var obsAutoStartRecording: Bool = false
    var obsAutoStopRecording: Bool = false
    var discordSnapshotWebhook: String = ""
    var discordChatBotSnapshotWebhook: String = ""
    @Published var discordSnapshotWebhookOnlyWhenLive: Bool = true
    @Published var resolution: SettingsStreamResolution = SettingsStream.defaultResolution
    @Published var fps: Int = SettingsStream.defaultFps
    @Published var autoFps: Bool = false
    @Published var bitrate: UInt32 = 5_000_000
    @Published var codec: SettingsStreamCodec = .h265hevc
    @Published var h264Profile: SettingsStreamH264Profile = .main
    @Published var bFrames: Bool = false
    @Published var adaptiveEncoderResolution: Bool = false
    var adaptiveBitrate: Bool = true
    var srt: SettingsStreamSrt = .init()
    var rtmp: SettingsStreamRtmp = .init()
    var rist: SettingsStreamRist = .init()
    @Published var maxKeyFrameInterval: Int32 = 2
    @Published var audioCodec: SettingsStreamAudioCodec = .aac
    var audioBitrate: Int = 128_000
    var chat: SettingsStreamChat = .init()
    var recording: SettingsStreamRecording = .init()
    @Published var realtimeIrlEnabled: Bool = false
    @Published var realtimeIrlBaseUrl = defaultRealtimeIrlBaseUrl
    @Published var realtimeIrlPushKey: String = ""
    @Published var portrait: Bool = false
    @Published var backgroundStreaming: Bool = false
    @Published var estimatedViewerDelay: Float = 8.0
    @Published var ntpPoolAddress: String = "time.apple.com"
    @Published var timecodesEnabled: Bool = false
    var replay: SettingsStreamReplay = .init()
    @Published var goLiveNotificationDiscordMessage: String = ""
    @Published var goLiveNotificationDiscordWebhookUrl: String = ""
    @Published var multiStreaming: SettingsStreamMultiStreaming = .init()

    static func == (lhs: SettingsStream, rhs: SettingsStream) -> Bool {
        lhs.id == rhs.id
    }

    init(name: String) {
        self.name = name
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             enabled,
             url,
             twitchChannelName,
             twitchChannelId,
             twitchShowFollows,
             twitchChatAlerts,
             twitchToastAlerts,
             twitchAccessToken,
             twitchLoggedIn,
             twitchRewards,
             twitchSendMessagesTo,
             kickChannelName,
             kickChannelId,
             kickChatroomChannelId,
             kickSlug,
             kickAccessToken,
             kickLoggedIn,
             kickSendMessagesTo,
             kickChatAlerts,
             kickToastAlerts,
             youTubeApiKey,
             youTubeVideoId,
             youTubeHandle,
             afreecaTvChannelName,
             afreecaTvStreamId,
             openStreamingPlatformUrl,
             openStreamingPlatformChannelId,
             obsWebSocketEnabled,
             obsWebSocketUrl,
             obsWebSocketPassword,
             obsSourceName,
             obsMainScene,
             obsBrbScene,
             obsBrbSceneVideoSourceBroken,
             obsAutoStartStream,
             obsAutoStopStream,
             obsAutoStartRecording,
             obsAutoStopRecording,
             discordSnapshotWebhook,
             discordChatBotSnapshotWebhook,
             discordSnapshotWebhookOnlyWhenLive,
             resolution,
             fps,
             autoFps,
             bitrate,
             codec,
             h264Profile,
             bFrames,
             adaptiveEncoderResolution,
             adaptiveBitrate,
             srt,
             rtmp,
             rist,
             captureSessionPresetEnabled,
             captureSessionPreset,
             maxKeyFrameInterval,
             audioCodec,
             audioBitrate,
             chat,
             recording,
             realtimeIrlEnabled,
             realtimeIrlBaseUrl,
             realtimeIrlPushKey,
             portrait,
             backgroundStreaming,
             estimatedViewerDelay,
             ntpPoolAddress,
             timecodesEnabled,
             replay,
             goLiveNotificationDiscordMessage,
             goLiveNotificationDiscordWebhookUrl,
             multiStreaming
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.url, url)
        try container.encode(.twitchChannelName, twitchChannelName)
        try container.encode(.twitchChannelId, twitchChannelId)
        try container.encode(.twitchShowFollows, twitchShowFollows)
        try container.encode(.twitchAccessToken, twitchAccessToken)
        try container.encode(.twitchLoggedIn, twitchLoggedIn)
        try container.encode(.twitchRewards, twitchRewards)
        try container.encode(.twitchSendMessagesTo, twitchSendMessagesTo)
        try container.encode(.twitchChatAlerts, twitchChatAlerts)
        try container.encode(.twitchToastAlerts, twitchToastAlerts)
        try container.encode(.kickChannelName, kickChannelName)
        try container.encode(.kickChannelId, kickChannelId)
        try container.encode(.kickChatroomChannelId, kickChatroomChannelId)
        try container.encode(.kickSlug, kickSlug)
        try container.encode(.kickAccessToken, kickAccessToken)
        try container.encode(.kickLoggedIn, kickLoggedIn)
        try container.encode(.kickSendMessagesTo, kickSendMessagesTo)
        try container.encode(.kickChatAlerts, kickChatAlerts)
        try container.encode(.kickToastAlerts, kickToastAlerts)
        try container.encode(.youTubeApiKey, youTubeApiKey)
        try container.encode(.youTubeVideoId, youTubeVideoId)
        try container.encode(.youTubeHandle, youTubeHandle)
        try container.encode(.afreecaTvChannelName, soopChannelName)
        try container.encode(.afreecaTvStreamId, soopStreamId)
        try container.encode(.openStreamingPlatformUrl, openStreamingPlatformUrl)
        try container.encode(.openStreamingPlatformChannelId, openStreamingPlatformChannelId)
        try container.encode(.obsWebSocketEnabled, obsWebSocketEnabled)
        try container.encode(.obsWebSocketUrl, obsWebSocketUrl)
        try container.encode(.obsWebSocketPassword, obsWebSocketPassword)
        try container.encode(.obsSourceName, obsSourceName)
        try container.encode(.obsMainScene, obsMainScene)
        try container.encode(.obsBrbScene, obsBrbScene)
        try container.encode(.obsBrbSceneVideoSourceBroken, obsBrbSceneVideoSourceBroken)
        try container.encode(.obsAutoStartStream, obsAutoStartStream)
        try container.encode(.obsAutoStopStream, obsAutoStopStream)
        try container.encode(.obsAutoStartRecording, obsAutoStartRecording)
        try container.encode(.obsAutoStopRecording, obsAutoStopRecording)
        try container.encode(.discordSnapshotWebhook, discordSnapshotWebhook)
        try container.encode(.discordChatBotSnapshotWebhook, discordChatBotSnapshotWebhook)
        try container.encode(.discordSnapshotWebhookOnlyWhenLive, discordSnapshotWebhookOnlyWhenLive)
        try container.encode(.resolution, resolution)
        try container.encode(.fps, fps)
        try container.encode(.autoFps, autoFps)
        try container.encode(.bitrate, bitrate)
        try container.encode(.codec, codec)
        try container.encode(.h264Profile, h264Profile)
        try container.encode(.bFrames, bFrames)
        try container.encode(.adaptiveEncoderResolution, adaptiveEncoderResolution)
        try container.encode(.adaptiveBitrate, adaptiveBitrate)
        try container.encode(.srt, srt)
        try container.encode(.rtmp, rtmp)
        try container.encode(.rist, rist)
        try container.encode(.maxKeyFrameInterval, maxKeyFrameInterval)
        try container.encode(.audioCodec, audioCodec)
        try container.encode(.audioBitrate, audioBitrate)
        try container.encode(.chat, chat)
        try container.encode(.recording, recording)
        try container.encode(.realtimeIrlEnabled, realtimeIrlEnabled)
        try container.encode(.realtimeIrlBaseUrl, realtimeIrlBaseUrl)
        try container.encode(.realtimeIrlPushKey, realtimeIrlPushKey)
        try container.encode(.portrait, portrait)
        try container.encode(.backgroundStreaming, backgroundStreaming)
        try container.encode(.estimatedViewerDelay, estimatedViewerDelay)
        try container.encode(.ntpPoolAddress, ntpPoolAddress)
        try container.encode(.timecodesEnabled, timecodesEnabled)
        try container.encode(.replay, replay)
        try container.encode(.goLiveNotificationDiscordMessage, goLiveNotificationDiscordMessage)
        try container.encode(.goLiveNotificationDiscordWebhookUrl, goLiveNotificationDiscordWebhookUrl)
        try container.encode(.multiStreaming, multiStreaming)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "My stream")
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, false)
        url = container.decode(.url, String.self, defaultStreamUrl)
        twitchChannelName = container.decode(.twitchChannelName, String.self, "")
        twitchChannelId = container.decode(.twitchChannelId, String.self, "")
        twitchShowFollows = container.decode(.twitchShowFollows, Bool?.self, nil)
        twitchAccessToken = container.decode(.twitchAccessToken, String.self, "")
        twitchLoggedIn = container.decode(.twitchLoggedIn, Bool.self, false)
        twitchRewards = container.decode(.twitchRewards, [SettingsStreamTwitchReward].self, [])
        twitchSendMessagesTo = container.decode(.twitchSendMessagesTo, Bool.self, true)
        twitchChatAlerts = container.decode(.twitchChatAlerts, SettingsTwitchAlerts.self, .init())
        twitchToastAlerts = container.decode(.twitchToastAlerts, SettingsTwitchAlerts.self, .init())
        if let twitchShowFollows {
            twitchChatAlerts.follows = twitchShowFollows
            twitchToastAlerts.follows = twitchShowFollows
        }
        twitchShowFollows = nil
        kickChannelName = container.decode(.kickChannelName, String.self, "")
        kickChannelId = container.decode(.kickChannelId, String?.self, nil)
        kickChatroomChannelId = container.decode(.kickChatroomChannelId, String?.self, nil)
        kickSlug = container.decode(.kickSlug, String?.self, nil)
        kickAccessToken = container.decode(.kickAccessToken, String.self, "")
        kickLoggedIn = container.decode(.kickLoggedIn, Bool.self, false)
        kickSendMessagesTo = container.decode(.kickSendMessagesTo, Bool.self, true)
        kickChatAlerts = container.decode(.kickChatAlerts, SettingsKickAlerts.self, .init())
        kickToastAlerts = container.decode(.kickToastAlerts, SettingsKickAlerts.self, .init())
        youTubeApiKey = container.decode(.youTubeApiKey, String.self, "")
        youTubeVideoId = container.decode(.youTubeVideoId, String.self, "")
        youTubeHandle = container.decode(.youTubeHandle, String.self, "")
        soopChannelName = container.decode(.afreecaTvChannelName, String.self, "")
        soopStreamId = container.decode(.afreecaTvStreamId, String.self, "")
        openStreamingPlatformUrl = container.decode(.openStreamingPlatformUrl, String.self, "")
        openStreamingPlatformChannelId = container.decode(.openStreamingPlatformChannelId, String.self, "")
        obsWebSocketEnabled = container.decode(.obsWebSocketEnabled, Bool.self, false)
        obsWebSocketUrl = container.decode(.obsWebSocketUrl, String.self, "")
        obsWebSocketPassword = container.decode(.obsWebSocketPassword, String.self, "")
        obsSourceName = container.decode(.obsSourceName, String.self, "")
        obsMainScene = container.decode(.obsMainScene, String.self, "")
        obsBrbScene = container.decode(.obsBrbScene, String.self, "")
        obsBrbSceneVideoSourceBroken = container.decode(.obsBrbSceneVideoSourceBroken, Bool.self, false)
        obsAutoStartStream = container.decode(.obsAutoStartStream, Bool.self, false)
        obsAutoStopStream = container.decode(.obsAutoStopStream, Bool.self, false)
        obsAutoStartRecording = container.decode(.obsAutoStartRecording, Bool.self, false)
        obsAutoStopRecording = container.decode(.obsAutoStopRecording, Bool.self, false)
        discordSnapshotWebhook = container.decode(.discordSnapshotWebhook, String.self, "")
        discordChatBotSnapshotWebhook = container.decode(.discordChatBotSnapshotWebhook, String.self, "")
        discordSnapshotWebhookOnlyWhenLive = container.decode(.discordSnapshotWebhookOnlyWhenLive, Bool.self, true)
        resolution = container.decode(.resolution, SettingsStreamResolution.self, Self.defaultResolution)
        fps = container.decode(.fps, Int.self, Self.defaultFps)
        autoFps = container.decode(.autoFps, Bool.self, false)
        bitrate = container.decode(.bitrate, UInt32.self, 5_000_000)
        codec = container.decode(.codec, SettingsStreamCodec.self, .h265hevc)
        h264Profile = container.decode(.h264Profile, SettingsStreamH264Profile.self, .main)
        bFrames = container.decode(.bFrames, Bool.self, false)
        adaptiveEncoderResolution = container.decode(.adaptiveEncoderResolution, Bool.self, false)
        adaptiveBitrate = container.decode(.adaptiveBitrate, Bool.self, true)
        srt = container.decode(.srt, SettingsStreamSrt.self, .init())
        rtmp = container.decode(.rtmp, SettingsStreamRtmp.self, .init())
        rist = container.decode(.rist, SettingsStreamRist.self, .init())
        maxKeyFrameInterval = container.decode(.maxKeyFrameInterval, Int32.self, 2)
        audioCodec = container.decode(.audioCodec, SettingsStreamAudioCodec.self, .aac)
        audioBitrate = container.decode(.audioBitrate, Int.self, 128_000)
        chat = container.decode(.chat, SettingsStreamChat.self, .init())
        recording = container.decode(.recording, SettingsStreamRecording.self, .init())
        realtimeIrlEnabled = container.decode(.realtimeIrlEnabled, Bool.self, false)
        realtimeIrlBaseUrl = container.decode(.realtimeIrlBaseUrl, String.self, Self.defaultRealtimeIrlBaseUrl)
        realtimeIrlPushKey = container.decode(.realtimeIrlPushKey, String.self, "")
        portrait = container.decode(.portrait, Bool.self, false)
        backgroundStreaming = container.decode(.backgroundStreaming, Bool.self, false)
        estimatedViewerDelay = container.decode(.estimatedViewerDelay, Float.self, 8.0)
        ntpPoolAddress = container.decode(.ntpPoolAddress, String.self, "time.apple.com")
        timecodesEnabled = container.decode(.timecodesEnabled, Bool.self, false)
        replay = container.decode(.replay, SettingsStreamReplay.self, .init())
        goLiveNotificationDiscordMessage = container.decode(.goLiveNotificationDiscordMessage, String.self, "")
        goLiveNotificationDiscordWebhookUrl = container.decode(.goLiveNotificationDiscordWebhookUrl, String.self, "")
        multiStreaming = container.decode(.multiStreaming, SettingsStreamMultiStreaming.self, .init())
    }

    func clone() -> SettingsStream {
        let new = SettingsStream(name: name)
        new.url = url
        new.twitchChannelName = twitchChannelName
        new.twitchChannelId = twitchChannelId
        new.twitchShowFollows = twitchShowFollows
        new.twitchRewards = twitchRewards
        new.twitchSendMessagesTo = twitchSendMessagesTo
        new.twitchChatAlerts = twitchChatAlerts.clone()
        new.twitchToastAlerts = twitchToastAlerts.clone()
        new.kickChannelName = kickChannelName
        new.kickChannelId = kickChannelId
        new.kickChatroomChannelId = kickChatroomChannelId
        new.kickSlug = kickSlug
        new.kickAccessToken = kickAccessToken
        new.kickLoggedIn = kickLoggedIn
        new.kickSendMessagesTo = kickSendMessagesTo
        new.kickChatAlerts = kickChatAlerts.clone()
        new.kickToastAlerts = kickToastAlerts.clone()
        new.youTubeApiKey = youTubeApiKey
        new.youTubeVideoId = youTubeVideoId
        new.youTubeHandle = youTubeHandle
        new.soopChannelName = soopChannelName
        new.soopStreamId = soopStreamId
        new.openStreamingPlatformUrl = openStreamingPlatformUrl
        new.openStreamingPlatformChannelId = openStreamingPlatformChannelId
        new.obsWebSocketEnabled = obsWebSocketEnabled
        new.obsWebSocketUrl = obsWebSocketUrl
        new.obsWebSocketPassword = obsWebSocketPassword
        new.obsSourceName = obsSourceName
        new.obsBrbScene = obsBrbScene
        new.obsMainScene = obsMainScene
        new.obsBrbSceneVideoSourceBroken = obsBrbSceneVideoSourceBroken
        new.obsAutoStartStream = obsAutoStartStream
        new.obsAutoStopStream = obsAutoStopStream
        new.obsAutoStartRecording = obsAutoStartRecording
        new.obsAutoStopRecording = obsAutoStopRecording
        new.discordSnapshotWebhook = discordSnapshotWebhook
        new.discordChatBotSnapshotWebhook = discordChatBotSnapshotWebhook
        new.discordSnapshotWebhookOnlyWhenLive = discordSnapshotWebhookOnlyWhenLive
        new.resolution = resolution
        new.fps = fps
        new.autoFps = autoFps
        new.bitrate = bitrate
        new.codec = codec
        new.h264Profile = h264Profile
        new.bFrames = bFrames
        new.adaptiveEncoderResolution = adaptiveEncoderResolution
        new.adaptiveBitrate = adaptiveBitrate
        new.srt = srt.clone()
        new.rtmp = rtmp.clone()
        new.rist = rist.clone()
        new.maxKeyFrameInterval = maxKeyFrameInterval
        new.audioCodec = audioCodec
        new.audioBitrate = audioBitrate
        new.chat = chat.clone()
        new.recording = recording.clone()
        new.realtimeIrlEnabled = realtimeIrlEnabled
        new.realtimeIrlBaseUrl = realtimeIrlBaseUrl
        new.realtimeIrlPushKey = realtimeIrlPushKey
        new.portrait = portrait
        new.backgroundStreaming = backgroundStreaming
        new.estimatedViewerDelay = estimatedViewerDelay
        new.ntpPoolAddress = ntpPoolAddress
        new.timecodesEnabled = timecodesEnabled
        new.replay = replay.clone()
        new.goLiveNotificationDiscordMessage = goLiveNotificationDiscordMessage
        new.goLiveNotificationDiscordWebhookUrl = goLiveNotificationDiscordWebhookUrl
        new.multiStreaming = multiStreaming.clone()
        return new
    }

    func getScheme() -> String? {
        return URL(string: url)?.scheme
    }

    func getProtocol() -> SettingsStreamProtocol {
        switch getScheme() {
        case "rtmp":
            return .rtmp
        case "rtmps":
            return .rtmp
        case "srt":
            return .srt
        case "srtla":
            return .srt
        case "rist":
            return .rist
        default:
            return .rtmp
        }
    }

    func getDetailedProtocol() -> SettingsStreamDetailedProtocol {
        switch getScheme() {
        case "rtmp":
            return .rtmp
        case "rtmps":
            return .rtmps
        case "srt":
            return .srt
        case "srtla":
            return .srtla
        case "rist":
            return .rist
        default:
            return .rtmp
        }
    }

    func protocolString() -> String {
        if getProtocol() == .srt && isSrtla() {
            return "SRTLA"
        } else if getProtocol() == .rtmp && isRtmps() {
            return "RTMPS"
        } else {
            return getProtocol().rawValue
        }
    }

    func isRtmps() -> Bool {
        return getScheme() == "rtmps"
    }

    func isSrtla() -> Bool {
        return getScheme() == "srtla"
    }

    func isBonding() -> Bool {
        if isSrtla() {
            return true
        }
        if getProtocol() == .rist && rist.bonding {
            return true
        }
        return false
    }

    func resolutionString() -> String {
        return resolution.shortString()
    }

    func dimensions() -> CMVideoDimensions {
        return resolution.dimensions(portrait: portrait)
    }

    func codecString() -> String {
        return codec.shortString()
    }

    func bitrateString() -> String {
        var bitrate = formatBytesPerSecond(speed: Int64(bitrate))
        if getProtocol() == .srt && srt.adaptiveBitrateEnabled {
            bitrate = "<\(bitrate)"
        } else if getProtocol() == .rtmp && rtmp.adaptiveBitrateEnabled {
            bitrate = "<\(bitrate)"
        }
        return bitrate
    }

    func audioBitrateString() -> String {
        return formatBytesPerSecond(speed: Int64(audioBitrate))
    }

    func audioCodecString() -> String {
        return audioCodec.toString()
    }

    func maxKeyFrameIntervalString() -> String {
        if maxKeyFrameInterval != 0 {
            return "\(maxKeyFrameInterval) s"
        } else {
            return String(localized: "Auto")
        }
    }
}
