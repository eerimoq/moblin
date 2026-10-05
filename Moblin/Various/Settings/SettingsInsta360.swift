import Foundation
import SwiftUI

class SettingsInsta360: Codable, ObservableObject {
    var id: UUID = .init()
    @Published var enabled: Bool = false
    @Published var host: String = "192.168.42.1"
    @Published var latency: Int32 = 300

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case enabled
        case host
        case latency
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.host, host)
        try container.encode(.latency, latency)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, false)
        host = container.decode(.host, String.self, "192.168.42.1")
        latency = max(5, container.decode(.latency, Int32.self, 300))
    }

    func latencySeconds() -> Double {
        Double(latency) / 1000
    }

    func camera() -> String {
        String(localized: "Insta360 GO Ultra")
    }
}
