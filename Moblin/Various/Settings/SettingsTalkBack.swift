import Foundation

class SettingsTalkBack: Codable, ObservableObject {
    @Published var videoSourceId: UUID = .init()
    @Published var audioSourceId: UUID = .init()

    enum CodingKeys: CodingKey {
        case videoSourceId
        case audioSourceId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.videoSourceId, videoSourceId)
        try container.encode(.audioSourceId, audioSourceId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        videoSourceId = container.decode(.videoSourceId, UUID.self, .init())
        audioSourceId = container.decode(.audioSourceId, UUID.self, .init())
    }
}
