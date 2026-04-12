import Foundation

class SettingsSelfieStick: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var function: SettingsControllerFunction = .switchScene
    @Published var sceneId: UUID?
    @Published var widgetId: UUID?
    @Published var gimbalPresetId: UUID?

    enum CodingKeys: CodingKey {
        case enabled,
             function,
             sceneId,
             widgetId,
             gimbalPresetId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
        try container.encode(.widgetId, widgetId)
        try container.encode(.gimbalPresetId, gimbalPresetId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        function = container.decode(.function, SettingsControllerFunction.self, .switchScene)
        sceneId = container.decode(.sceneId, UUID?.self, nil)
        widgetId = container.decode(.widgetId, UUID?.self, nil)
        gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
    }
}
