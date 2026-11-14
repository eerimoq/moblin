import Foundation

class SettingsHttpProxy: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var localNetwork: Bool = false
    @Published var port: UInt16 = DefaultTcpPorts.httpProxy

    enum CodingKeys: CodingKey {
        case enabled
        case localNetwork
        case port
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.localNetwork, localNetwork)
        try container.encode(.port, port)
    }

    init() {}

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        localNetwork = container.decode(.localNetwork, Bool.self, false)
        port = container.decode(.port, UInt16.self, DefaultTcpPorts.httpProxy)
    }
}
