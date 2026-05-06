import Foundation

class SettingsKeyboardKey: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var key: String = ""
    @Published var function: SettingsControllerFunction = .unused
    @Published var functionData: SettingsControllerFunctionData = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             key,
             function,
             sceneId,
             widgetId,
             gimbalPresetId,
             gimbalMotion,
             macroId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.key, key)
        try container.encode(.function, function)
        try container.encode(.sceneId, functionData.sceneId)
        try container.encode(.widgetId, functionData.widgetId)
        try container.encode(.gimbalPresetId, functionData.gimbalPresetId)
        try container.encode(.gimbalMotion, functionData.gimbalMotion)
        try container.encode(.macroId, functionData.macroId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        key = container.decode(.key, String.self, "")
        function = container.decode(.function, SettingsControllerFunction.self, .unused)
        functionData.sceneId = container.decode(.sceneId, UUID?.self, nil)
        functionData.widgetId = container.decode(.widgetId, UUID?.self, nil)
        functionData.gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
        functionData.gimbalMotion = container.decode(.gimbalMotion, SettingsGimbalMotion.self, .kapow)
        functionData.macroId = container.decode(.macroId, UUID?.self, nil)
    }
}

class SettingsKeyboard: Codable, ObservableObject {
    @Published var keys: [SettingsKeyboardKey] = []

    init() {}

    enum CodingKeys: CodingKey {
        case keys
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.keys, keys)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keys = container.decode(.keys, [SettingsKeyboardKey].self, [])
    }
}
