import Foundation

class SettingsGimbal: Codable, ObservableObject {
    static let zoomSpeedDefault: Float = 50
    @Published var zoomSpeed: Float = zoomSpeedDefault
    @Published var naturalZoom: Bool = true
    @Published var functionShutter: SettingsControllerFunction = .record
    @Published var shutterSceneId: UUID?
    @Published var shutterWidgetId: UUID?
    @Published var functionFlip: SettingsControllerFunction = .switchScene
    @Published var flipSceneId: UUID?
    @Published var flipWidgetId: UUID?

    enum CodingKeys: CodingKey {
        case zoomSpeed,
             naturalZoom,
             functionShutter,
             shutterSceneId,
             shutterWidgetId,
             functionFlip,
             flipSceneId,
             flipWidgetId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.zoomSpeed, zoomSpeed)
        try container.encode(.naturalZoom, naturalZoom)
        try container.encode(.functionShutter, functionShutter)
        try container.encode(.shutterSceneId, shutterSceneId)
        try container.encode(.shutterWidgetId, shutterWidgetId)
        try container.encode(.functionFlip, functionFlip)
        try container.encode(.flipSceneId, flipSceneId)
        try container.encode(.flipWidgetId, flipWidgetId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zoomSpeed = container.decode(.zoomSpeed, Float.self, Self.zoomSpeedDefault)
        naturalZoom = container.decode(.naturalZoom, Bool.self, true)
        functionShutter = container.decode(.functionShutter, SettingsControllerFunction.self, .record)
        shutterSceneId = container.decode(.shutterSceneId, UUID?.self, nil)
        shutterWidgetId = container.decode(.shutterWidgetId, UUID?.self, nil)
        functionFlip = container.decode(.functionFlip, SettingsControllerFunction.self, .switchScene)
        flipSceneId = container.decode(.flipSceneId, UUID?.self, nil)
        flipWidgetId = container.decode(.flipWidgetId, UUID?.self, nil)
    }
}
