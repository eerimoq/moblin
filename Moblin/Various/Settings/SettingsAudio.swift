import Foundation

enum SettingsMic: String, Codable, CaseIterable {
    case bottom = "Bottom"
    case front = "Front"
    case back = "Back"
    case top = "Top"

    init(from decoder: any Decoder) throws {
        self = try SettingsMic(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            getDefaultMic()
    }
}

class SettingsMicsMic: Codable, Identifiable, Equatable, ObservableObject, @unchecked Sendable {
    static func == (lhs: SettingsMicsMic, rhs: SettingsMicsMic) -> Bool {
        lhs.inputUid == rhs.inputUid && lhs.dataSourceId == rhs.dataSourceId
    }

    var id: String {
        "\(inputUid) \(dataSourceId ?? 0)"
    }

    var name: String = ""
    var inputUid: String = ""
    var dataSourceId: Int?
    var builtInOrientation: SettingsMic?
    @Published var connected: Bool = false

    func isAudioSession() -> Bool {
        isBuiltin() || isExternal()
    }

    func isBuiltin() -> Bool {
        builtInOrientation != nil
    }

    func isExternal() -> Bool {
        if isBuiltin() {
            return false
        }
        if isRtmpCameraOrMic(camera: name) {
            return false
        }
        if isSrtlaCameraOrMic(camera: name) {
            return false
        }
        if isRistCameraOrMic(camera: name) {
            return false
        }
        if isRtspCameraOrMic(camera: name) {
            return false
        }
        if isWhipCameraOrMic(camera: name) {
            return false
        }
        if isWhepCameraOrMic(camera: name) {
            return false
        }
        if isMediaPlayerCameraOrMic(camera: name) {
            return false
        }
        return true
    }

    func isRtmp() -> Bool {
        isRtmpCameraOrMic(camera: name)
    }

    func isSrtla() -> Bool {
        isSrtlaCameraOrMic(camera: name)
    }

    func isRist() -> Bool {
        isRistCameraOrMic(camera: name)
    }

    func isRtsp() -> Bool {
        isRtspCameraOrMic(camera: name)
    }

    func isWhip() -> Bool {
        isWhipCameraOrMic(camera: name)
    }

    func isWhep() -> Bool {
        isWhepCameraOrMic(camera: name)
    }

    func isNetwork() -> Bool {
        isRtmp() || isSrtla() || isRist() || isRtsp() || isWhip() || isWhep()
    }

    func isMediaPlayer() -> Bool {
        isMediaPlayerCameraOrMic(camera: name)
    }

    enum CodingKeys: CodingKey {
        case name
        case inputUid
        case dataSourceID
        case builtInOrientation
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.inputUid, inputUid)
        try container.encode(.dataSourceID, dataSourceId)
        try container.encode(.builtInOrientation, builtInOrientation)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        inputUid = container.decode(.inputUid, String.self, "")
        dataSourceId = container.decode(.dataSourceID, Int?.self, nil)
        builtInOrientation = container.decode(.builtInOrientation, SettingsMic?.self, nil)
    }
}

class SettingsMics: Codable, ObservableObject {
    @Published var mics: [SettingsMicsMic] = []
    @Published var autoSwitch: Bool = true
    var defaultMic: String = ""

    enum CodingKeys: CodingKey {
        case all
        case autoSwitch
        case defaultMic
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.all, mics)
        try container.encode(.autoSwitch, autoSwitch)
        try container.encode(.defaultMic, defaultMic)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mics = container.decode(.all, [SettingsMicsMic].self, [])
        autoSwitch = container.decode(.autoSwitch, Bool.self, true)
        defaultMic = container.decode(.defaultMic, String.self, "")
    }
}

class SettingsAudioOutputToInputChannelsMap: Codable {
    var channel1: Int = 0
    var channel2: Int = 1
}

class SettingsAudio: Codable, ObservableObject {
    var outputToInputChannelsMap: SettingsAudioOutputToInputChannelsMap = .init()
    @Published var gainDb: Float = 0.0

    init() {}

    enum CodingKeys: CodingKey {
        case audioOutputToInputChannelsMap
        case gainDb
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.audioOutputToInputChannelsMap, outputToInputChannelsMap)
        try container.encode(.gainDb, gainDb)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputToInputChannelsMap = container.decode(.audioOutputToInputChannelsMap,
                                                    SettingsAudioOutputToInputChannelsMap.self,
                                                    .init())
        gainDb = container.decode(.gainDb, Float.self, 0.0)
    }
}
