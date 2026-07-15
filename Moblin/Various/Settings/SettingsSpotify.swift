import Foundation

class SettingsSpotify: Codable, ObservableObject {
    @Published var enabled: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case enabled
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
    }
}
