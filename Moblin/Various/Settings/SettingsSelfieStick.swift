import Foundation

class SettingsSelfieStick: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var function: SettingsControllerFunction = .switchScene
    @Published var functionData: SettingsControllerFunctionData = .init()

    enum CodingKeys: CodingKey {
        case enabled,
             function,
             sceneId,
             widgetId,
             gimbalPresetId,
             gimbalMotion,
             macroId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.function, function)
        try container.encode(.sceneId, functionData.sceneId)
        try container.encode(.widgetId, functionData.widgetId)
        try container.encode(.gimbalPresetId, functionData.gimbalPresetId)
        try container.encode(.gimbalMotion, functionData.gimbalMotion)
        try container.encode(.macroId, functionData.macroId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        function = container.decode(.function, SettingsControllerFunction.self, .switchScene)
        functionData.sceneId = container.decode(.sceneId, UUID?.self, nil)
        functionData.widgetId = container.decode(.widgetId, UUID?.self, nil)
        functionData.gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
        functionData.gimbalMotion = container.decode(.gimbalMotion, SettingsGimbalMotion.self, .kapow)
        functionData.macroId = container.decode(.macroId, UUID?.self, nil)
    }
}
