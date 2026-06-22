import SwiftUI

class SettingsStreamDeckKey: Codable, ObservableObject, Identifiable {
    static let defaultColor = RgbColor.white
    var id: UUID = .init()
    @Published var text: String = ""
    var color: RgbColor = defaultColor
    @Published var colorColor: Color = defaultColor.color()
    @Published var function: SettingsControllerFunction = .unused
    @Published var functionData: SettingsControllerFunctionData = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case text
        case color
        case function
        case sceneId
        case widgetId
        case gimbalPresetId
        case gimbalMotion
        case macroId
        case streamDeckLayoutId
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.text, text)
        try container.encode(.color, color)
        try container.encode(.function, function)
        try container.encode(.sceneId, functionData.sceneId)
        try container.encode(.widgetId, functionData.widgetId)
        try container.encode(.gimbalPresetId, functionData.gimbalPresetId)
        try container.encode(.gimbalMotion, functionData.gimbalMotion)
        try container.encode(.macroId, functionData.macroId)
        try container.encode(.streamDeckLayoutId, functionData.streamDeckLayoutId)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        text = container.decode(.text, String.self, "")
        color = container.decode(.color, RgbColor.self, .white)
        colorColor = color.color()
        function = container.decode(.function, SettingsControllerFunction.self, .unused)
        functionData.sceneId = container.decode(.sceneId, UUID?.self, nil)
        functionData.widgetId = container.decode(.widgetId, UUID?.self, nil)
        functionData.gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
        functionData.gimbalMotion = container.decode(.gimbalMotion, SettingsGimbalMotion.self, .kapow)
        functionData.macroId = container.decode(.macroId, UUID?.self, nil)
        functionData.streamDeckLayoutId = container.decode(.streamDeckLayoutId, UUID?.self, nil)
    }
}

class SettingsStreamDeckLayout: Codable, ObservableObject, Identifiable, Named {
    static let baseName = "My layout"
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var keys: [SettingsStreamDeckKey] = []

    init() {
        for _ in 0 ..< 36 {
            keys.append(.init())
        }
    }

    enum CodingKeys: CodingKey {
        case id
        case name
        case keys
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.keys, keys)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        keys = container.decode(.keys, [SettingsStreamDeckKey].self, [])
        for _ in keys.count ..< 36 {
            keys.append(.init())
        }
    }
}

class SettingsStreamDecks: Codable, ObservableObject {
    @Published var layouts: [SettingsStreamDeckLayout] = []
    @Published var selectedId: UUID?

    init() {}

    enum CodingKeys: CodingKey {
        case layouts
        case selectedId
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.layouts, layouts)
        try container.encode(.selectedId, selectedId)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layouts = container.decode(.layouts, [SettingsStreamDeckLayout].self, [])
        selectedId = container.decode(.selectedId, UUID?.self, nil)
    }
}
