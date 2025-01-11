import Foundation

let srtlaRelayApiVersion = "1.0"

enum SrtlaRelayRequest: Codable {
    case startTunnel(address: String, port: UInt16)
    case status
}

enum SrtlaRelayResponse: Codable {
    case startTunnel(port: UInt16)
    case status(batteryPercentage: Int?)
}

struct SrtlaRelayAuthentication: Codable {
    var challenge: String
    var salt: String
}

enum SrtlaRelayResult: Codable {
    case ok
    case wrongPassword
    case unknownRequest
    case notIdentified
    case alreadyIdentified
}

enum SrtlaRelayMessageToClient: Codable {
    case hello(apiVersion: String, id: UUID, name: String, authentication: SrtlaRelayAuthentication)
    case identified(result: SrtlaRelayResult)
    case response(id: Int, result: SrtlaRelayResult, data: SrtlaRelayResponse?)

    func toJson() -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(self), encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromJson(data: String) throws -> SrtlaRelayMessageToClient {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(SrtlaRelayMessageToClient.self, from: data)
    }
}

enum SrtlaRelayMessageToServer: Codable {
    case identify(authentication: String)
    case request(id: Int, data: SrtlaRelayRequest)

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> SrtlaRelayMessageToServer {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(SrtlaRelayMessageToServer.self, from: data)
    }
}
