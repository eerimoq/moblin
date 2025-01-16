import Foundation

let moblinkBonjourType = "_moblink._tcp"
let moblinkBonjourDomain = "local"

enum MoblinkRequest: Codable {
    case startTunnel(address: String, port: UInt16)
    case status
}

enum MoblinkResponse: Codable {
    case startTunnel(port: UInt16)
    case status(batteryPercentage: Int?)
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

enum MoblinkMessageToClient: Codable {
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

    static func fromJson(data: String) throws -> MoblinkMessageToClient {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MoblinkMessageToClient.self, from: data)
    }
}

enum MoblinkMessageToServer: Codable {
    case identify(id: UUID, name: String, authentication: String)
    case response(id: Int, result: MoblinkResult, data: MoblinkResponse?)

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> MoblinkMessageToServer {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MoblinkMessageToServer.self, from: data)
    }
}
