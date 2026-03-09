import Foundation

enum SettingsMetaGlassesResolution: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    func toString() -> String {
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

class SettingsMetaGlasses: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var autoStartStopStreaming: Bool = true
    @Published var fillFrame: Bool = false
    @Published var resolution: SettingsMetaGlassesResolution = .medium
    @Published var frameRate: Int = 30

    init() {}

    enum CodingKeys: CodingKey {
        case enabled,
             autoStartStopStreaming,
             fillFrame,
             resolution,
             frameRate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.autoStartStopStreaming, autoStartStopStreaming)
        try container.encode(.fillFrame, fillFrame)
        try container.encode(.resolution, resolution)
        try container.encode(.frameRate, frameRate)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        autoStartStopStreaming = container.decode(.autoStartStopStreaming, Bool.self, true)
        fillFrame = container.decode(.fillFrame, Bool.self, false)
        resolution = container.decode(.resolution, SettingsMetaGlassesResolution.self, .medium)
        frameRate = container.decode(.frameRate, Int.self, 30)
    }
}
