import Foundation

enum SettingsMic: String, Codable, CaseIterable {
    case bottom = "Bottom"
    case front = "Front"
    case back = "Back"
    case top = "Top"

    init(from decoder: Decoder) throws {
        self = try SettingsMic(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            getDefaultMic()
    }
}

class SettingsMicsMic: Codable, Identifiable, Equatable, ObservableObject {
    static func == (lhs: SettingsMicsMic, rhs: SettingsMicsMic) -> Bool {
        return lhs.inputUid == rhs.inputUid && lhs.dataSourceId == rhs.dataSourceId
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
        return isBuiltin() || isExternal()
    }

    func isBuiltin() -> Bool {
        return builtInOrientation != nil
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
        if isMediaPlayerCameraOrMic(camera: name) {
            return false
        }
        return true
    }

    func isAlwaysConnected() -> Bool {
        if builtInOrientation != nil {
            return true
        }
        if isMediaPlayerCameraOrMic(camera: name) {
            return true
        }
        return false
    }

    func isRtmp() -> Bool {
        return isRtmpCameraOrMic(camera: name)
    }

    func isSrtla() -> Bool {
        return isSrtlaCameraOrMic(camera: name)
    }

    func isRist() -> Bool {
        return isRistCameraOrMic(camera: name)
    }

    func isMediaPlayer() -> Bool {
        return isMediaPlayerCameraOrMic(camera: name)
    }

    enum CodingKeys: CodingKey {
        case name,
             inputUid,
             dataSourceID,
             builtInOrientation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.inputUid, inputUid)
        try container.encode(.dataSourceID, dataSourceId)
        try container.encode(.builtInOrientation, builtInOrientation)
    }

    init() {}

    required init(from decoder: Decoder) throws {
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
        case all,
             autoSwitch,
             defaultMic
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.all, mics)
        try container.encode(.autoSwitch, autoSwitch)
        try container.encode(.defaultMic, defaultMic)
    }

    init() {}

    required init(from decoder: Decoder) throws {
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

class AudioSettings: Codable {
    var audioOutputToInputChannelsMap: SettingsAudioOutputToInputChannelsMap = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case audioOutputToInputChannelsMap
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.audioOutputToInputChannelsMap, audioOutputToInputChannelsMap)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        audioOutputToInputChannelsMap = container.decode(.audioOutputToInputChannelsMap,
                                                         SettingsAudioOutputToInputChannelsMap.self,
                                                         .init())
    }
}
