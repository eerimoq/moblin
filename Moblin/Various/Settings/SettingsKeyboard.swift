import Foundation

class SettingsKeyboardKey: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var key: String = ""
    @Published var function: SettingsControllerFunction = .unused
    @Published var sceneId: UUID = .init()
    @Published var widgetId: UUID = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             key,
             function,
             sceneId,
             widgetId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.key, key)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
        try container.encode(.widgetId, widgetId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        key = container.decode(.key, String.self, "")
        function = container.decode(.function, SettingsControllerFunction.self, .unused)
        sceneId = container.decode(.sceneId, UUID.self, .init())
        widgetId = container.decode(.widgetId, UUID.self, .init())
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
