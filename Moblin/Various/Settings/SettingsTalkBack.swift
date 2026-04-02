import Foundation

class SettingsTalkBack: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var micId: String = ""

    enum CodingKeys: CodingKey {
        case enabled,
             micId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.micId, micId)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        micId = container.decode(.micId, String.self, "")
    }
}
