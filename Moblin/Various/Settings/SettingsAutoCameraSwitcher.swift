import Foundation

class SettingsAutoCameraSpeaker: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My speaker")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var sceneId: UUID?
    @Published var microphoneIds: [String] = []
    @Published var micWeight: Float = 1.0

    enum CodingKeys: CodingKey {
        case id,
             name,
             sceneId,
             microphoneIds,
             micWeight
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.sceneId, sceneId)
        try container.encode(.microphoneIds, microphoneIds)
        try container.encode(.micWeight, micWeight)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        sceneId = container.decode(.sceneId, UUID?.self, nil)
        microphoneIds = container.decode(.microphoneIds, [String].self, [])
        micWeight = container.decode(.micWeight, Float.self, 1.0)
    }
}

enum SettingsAutoCameraActivityLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low:
            return String(localized: "Low")
        case .medium:
            return String(localized: "Medium")
        case .high:
            return String(localized: "High")
        }
    }
}

class SettingsAutoCameraSwitcher: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My auto camera")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var enabled: Bool = false
    @Published var speakers: [SettingsAutoCameraSpeaker] = []
    @Published var wideShotSceneId: UUID?
    @Published var sensitivity: Float = 0.5
    @Published var switchCooldownMs: Int = 1500
    @Published var noiseFloorDb: Float = -50.0
    @Published var predictionBufferMs: Int = 200
    @Published var minShotDurationMs: Int = 2000
    @Published var wideShotIntervalSeconds: Int = 30
    @Published var maxSpeakerShotDurationSeconds: Int = 20
    @Published var activityLevel: SettingsAutoCameraActivityLevel = .medium
    @Published var smoothingFactor: Float = 0.3
    @Published var hysteresisDb: Float = 3.0

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             speakers,
             wideShotSceneId,
             sensitivity,
             switchCooldownMs,
             noiseFloorDb,
             predictionBufferMs,
             minShotDurationMs,
             wideShotIntervalSeconds,
             maxSpeakerShotDurationSeconds,
             activityLevel,
             smoothingFactor,
             hysteresisDb
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.speakers, speakers)
        try container.encode(.wideShotSceneId, wideShotSceneId)
        try container.encode(.sensitivity, sensitivity)
        try container.encode(.switchCooldownMs, switchCooldownMs)
        try container.encode(.noiseFloorDb, noiseFloorDb)
        try container.encode(.predictionBufferMs, predictionBufferMs)
        try container.encode(.minShotDurationMs, minShotDurationMs)
        try container.encode(.wideShotIntervalSeconds, wideShotIntervalSeconds)
        try container.encode(.maxSpeakerShotDurationSeconds, maxSpeakerShotDurationSeconds)
        try container.encode(.activityLevel, activityLevel)
        try container.encode(.smoothingFactor, smoothingFactor)
        try container.encode(.hysteresisDb, hysteresisDb)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        enabled = container.decode(.enabled, Bool.self, false)
        speakers = container.decode(.speakers, [SettingsAutoCameraSpeaker].self, [])
        wideShotSceneId = container.decode(.wideShotSceneId, UUID?.self, nil)
        sensitivity = container.decode(.sensitivity, Float.self, 0.5)
        switchCooldownMs = container.decode(.switchCooldownMs, Int.self, 1500)
        noiseFloorDb = container.decode(.noiseFloorDb, Float.self, -50.0)
        predictionBufferMs = container.decode(.predictionBufferMs, Int.self, 200)
        minShotDurationMs = container.decode(.minShotDurationMs, Int.self, 2000)
        wideShotIntervalSeconds = container.decode(.wideShotIntervalSeconds, Int.self, 30)
        maxSpeakerShotDurationSeconds = container.decode(.maxSpeakerShotDurationSeconds, Int.self, 20)
        activityLevel = container.decode(
            .activityLevel,
            SettingsAutoCameraActivityLevel.self,
            .medium
        )
        smoothingFactor = container.decode(.smoothingFactor, Float.self, 0.3)
        hysteresisDb = container.decode(.hysteresisDb, Float.self, 3.0)
    }
}

class SettingsAutoCameraSwitchers: Codable, Identifiable, ObservableObject {
    @Published var switcherId: UUID?
    @Published var switchers: [SettingsAutoCameraSwitcher] = []

    enum CodingKeys: CodingKey {
        case switcherId, switchers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.switcherId, switcherId)
        try container.encode(.switchers, switchers)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switcherId = try? container.decode(UUID?.self, forKey: .switcherId)
        switchers = container.decode(.switchers, [SettingsAutoCameraSwitcher].self, [])
    }
}
