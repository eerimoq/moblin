import Foundation

class SettingsNavigation: Codable, ObservableObject {
    @Published var followUser: Bool = false
    @Published var followHeading: Bool = false

    enum CodingKeys: CodingKey {
        case followUser,
             followHeading
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.followUser, followUser)
        try container.encode(.followHeading, followHeading)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        followUser = container.decode(.followUser, Bool.self, false)
        followHeading = container.decode(.followHeading, Bool.self, false)
    }
}
