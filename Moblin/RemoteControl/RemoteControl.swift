import CryptoKit
import Foundation

let remoteControlApiVersion = "0.1"

enum RemoteControlRequest: Codable {
    case getStatus
    case getSettings
    case setRecord(on: Bool)
    case setStream(on: Bool)
    case setZoom(x: Float)
    case setMute(on: Bool)
    case setTorch(on: Bool)
    case setScene(id: UUID)
    case setBitratePreset(id: UUID)
    case setMic(id: String)
    case setSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool)
    case setSrtConnectionPrioritiesEnabled(enabled: Bool)
    case reloadBrowserWidgets
}

enum RemoteControlResponse: Codable {
    case getStatus(
        general: RemoteControlStatusGeneral?,
        topLeft: RemoteControlStatusTopLeft,
        topRight: RemoteControlStatusTopRight
    )
    case getSettings(data: RemoteControlSettings)
}

enum RemoteControlEvent: Codable {
    case state(data: RemoteControlState)
    case log(entry: String)
}

struct RemoteControlStatusItem: Codable {
    var message: String
    var ok: Bool = true
}

enum RemoteControlStatusGeneralFlame: String, Codable {
    case white = "White"
    case yellow = "Yellow"
    case red = "Red"
    func toThermalState() -> ProcessInfo.ThermalState {
        switch self {
        case .white:
            return .fair
        case .yellow:
            return .serious
        case .red:
            return .critical
        }
    }
}

enum RemoteControlStatusGeneralAudioLevel: Codable {
    case muted
    case unknown
    case value(Float)
    func toFloat() -> Float {
        switch self {
        case .muted:
            return .nan
        case .unknown:
            return .infinity
        case let .value(value):
            return value
        }
    }
}

struct RemoteControlStatusGeneral: Codable {
    var batteryCharging: Bool?
    var batteryLevel: Int?
    var flame: RemoteControlStatusGeneralFlame?
    var wiFiSsid: String?
    var isLive: Bool?
    var isRecording: Bool?
}

struct RemoteControlStatusTopLeft: Codable {
    var stream: RemoteControlStatusItem?
    var camera: RemoteControlStatusItem?
    var mic: RemoteControlStatusItem?
    var zoom: RemoteControlStatusItem?
    var obs: RemoteControlStatusItem?
    var chat: RemoteControlStatusItem?
    var viewers: RemoteControlStatusItem?
}

struct RemoteControlStatusTopRight: Codable {
    var audioLevel: RemoteControlStatusGeneralAudioLevel?
    var numberOfAudioChannels: Int?
    var rtmpServer: RemoteControlStatusItem?
    var remoteControl: RemoteControlStatusItem?
    var gameController: RemoteControlStatusItem?
    var bitrate: RemoteControlStatusItem?
    var uptime: RemoteControlStatusItem?
    var location: RemoteControlStatusItem?
    var srtla: RemoteControlStatusItem?
    var recording: RemoteControlStatusItem?
    var browserWidgets: RemoteControlStatusItem?
}

struct RemoteControlSettingsScene: Codable, Identifiable {
    var id: UUID
    var name: String
}

struct RemoteControlSettingsBitratePreset: Codable, Identifiable {
    var id: UUID
    var bitrate: UInt32
}

struct RemoteControlSettingsMic: Codable, Identifiable {
    var id: String
    var name: String
}

struct RemoteControlSettingsSrtConnectionPriority: Codable, Identifiable {
    var id: UUID
    var name: String
    var priority: Int
    var enabled: Bool
}

struct RemoteControlSettingsSrt: Codable {
    var connectionPrioritiesEnabled: Bool
    var connectionPriorities: [RemoteControlSettingsSrtConnectionPriority]
}

struct RemoteControlSettings: Codable {
    var scenes: [RemoteControlSettingsScene]
    var bitratePresets: [RemoteControlSettingsBitratePreset]
    var mics: [RemoteControlSettingsMic]
    var srt: RemoteControlSettingsSrt
}

struct RemoteControlState: Codable {
    var scene: UUID?
    var mic: String?
    var bitrate: UUID?
    var zoom: Float?
}

struct RemoteControlAuthentication: Codable {
    var challenge: String
    var salt: String
}

enum RemoteControlResult: Codable {
    case ok
    case wrongPassword
    case unknownRequest
    case notIdentified
    case alreadyIdentified
}

enum RemoteControlMessageToStreamer: Codable {
    case hello(apiVersion: String, authentication: RemoteControlAuthentication)
    case identified(result: RemoteControlResult)
    case request(id: Int, data: RemoteControlRequest)

    func toJson() -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(self), encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromJson(data: String) throws -> RemoteControlMessageToStreamer {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(RemoteControlMessageToStreamer.self, from: data)
    }
}

enum RemoteControlMessageToAssistant: Codable {
    case identify(authentication: String)
    case response(id: Int, result: RemoteControlResult, data: RemoteControlResponse?)
    case event(data: RemoteControlEvent)
    case preview(preview: Data)

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> RemoteControlMessageToAssistant {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(RemoteControlMessageToAssistant.self, from: data)
    }
}

func remoteControlHashPassword(challenge: String, salt: String, password: String) -> String {
    var concatenated = "\(password)\(salt)"
    var hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
    concatenated = "\(hash.base64EncodedString())\(challenge)"
    hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
    return hash.base64EncodedString()
}
