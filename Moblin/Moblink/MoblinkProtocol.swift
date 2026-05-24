import Foundation

let moblinkBonjourType = "_moblink._tcp"
let moblinkBonjourDomain = "local"

enum MoblinkThermalState: String, Codable {
    case white
    case yellow
    case red
}

enum MoblinkRequest: Codable {
    case startTunnel(address: String, port: UInt16)
    case status
}

enum MoblinkResponse: Codable {
    case startTunnel(port: UInt16)
    case status(
        batteryPercentage: Int?,
        thermalState: MoblinkThermalState?,
        temperatureCelsius: Int?
    )

    private enum CodingKeys: String, CodingKey {
        case startTunnel
        case status
    }

    private enum StartTunnelCodingKeys: String, CodingKey {
        case port
    }

    private enum StatusCodingKeys: String, CodingKey {
        case batteryPercentage
        case thermalState
        case temperatureCelsius
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.startTunnel) {
            let startTunnel = try container.nestedContainer(
                keyedBy: StartTunnelCodingKeys.self,
                forKey: .startTunnel
            )
            self = .startTunnel(port: try startTunnel.decode(UInt16.self, forKey: .port))
            return
        }

        if container.contains(.status) {
            let status = try container.nestedContainer(keyedBy: StatusCodingKeys.self, forKey: .status)
            self = .status(
                batteryPercentage: try status.decodeIfPresent(Int.self, forKey: .batteryPercentage),
                thermalState: try status.decodeIfPresent(MoblinkThermalState.self, forKey: .thermalState),
                temperatureCelsius: try status.decodeIfPresent(Int.self, forKey: .temperatureCelsius)
            )
            return
        }

        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unknown MoblinkResponse case")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .startTunnel(port):
            var startTunnel = container.nestedContainer(keyedBy: StartTunnelCodingKeys.self,
                                                        forKey: .startTunnel)
            try startTunnel.encode(port, forKey: .port)
        case let .status(batteryPercentage, thermalState, temperatureCelsius):
            var status = container.nestedContainer(keyedBy: StatusCodingKeys.self, forKey: .status)
            try status.encodeIfPresent(batteryPercentage, forKey: .batteryPercentage)
            try status.encodeIfPresent(thermalState, forKey: .thermalState)
            try status.encodeIfPresent(temperatureCelsius, forKey: .temperatureCelsius)
        }
    }
}

struct MoblinkAuthentication: Codable {
    var challenge: String
    var salt: String
}

enum MoblinkResult: Codable {
    case ok
    case wrongPassword
    case unknownRequest
    case notIdentified
    case alreadyIdentified
}

enum MoblinkMessageToRelay: Codable {
    case hello(apiVersion: String, authentication: MoblinkAuthentication)
    case identified(result: MoblinkResult)
    case request(id: Int, data: MoblinkRequest)

    func toJson() -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(self), encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromJson(data: String) throws -> MoblinkMessageToRelay {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MoblinkMessageToRelay.self, from: data)
    }
}

enum MoblinkMessageToStreamer: Codable {
    case identify(id: UUID, name: String, authentication: String)
    case response(id: Int, result: MoblinkResult, data: MoblinkResponse?)

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> MoblinkMessageToStreamer {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MoblinkMessageToStreamer.self, from: data)
    }
}
