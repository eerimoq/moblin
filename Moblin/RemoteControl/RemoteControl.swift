import CryptoKit
import Foundation

let remoteControlApiVersion = "0.1"

enum RemoteControlRequest: Codable {
    case identify(authentication: String)
    case getStatus
}

struct RemoteControlStatusItem: Codable {
    var message: String
    var ok: Bool = true
}

struct RemoteControlStatusTopLeft: Codable {
    var stream: RemoteControlStatusItem?
    var camera: RemoteControlStatusItem?
    var mic: RemoteControlStatusItem?
    var zoom: RemoteControlStatusItem?
    var obs: RemoteControlStatusItem?
    var chat: RemoteControlStatusItem?
    var viewers: RemoteControlStatusItem?
}

struct RemoteControlStatusTopRight: Codable {
    var audioLevel: RemoteControlStatusItem?
    var rtmpServer: RemoteControlStatusItem?
    var gameController: RemoteControlStatusItem?
    var bitrate: RemoteControlStatusItem?
    var uptime: RemoteControlStatusItem?
    var location: RemoteControlStatusItem?
    var srtla: RemoteControlStatusItem?
    var recording: RemoteControlStatusItem?
}

enum RemoteControlResponse: Codable {
    case getStatus(topLeft: RemoteControlStatusTopLeft, topRight: RemoteControlStatusTopRight)
}

enum RemoteControlEvent: Codable {
    case hello(apiVersion: String, authentication: RemoteControlAuthentication)
}

enum RemoteControlResult: Codable {
    case ok
    case wrongPassword
}

struct RemoteControlAuthentication: Codable {
    var challenge: String
    var salt: String
}

enum RemoteControlMessageToServer: Codable {
    case request(id: Int, data: RemoteControlRequest)

    func toJson() -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(self), encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromJson(data: String) throws -> RemoteControlMessageToServer {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(RemoteControlMessageToServer.self, from: data)
    }
}

enum RemoteControlMessageToClient: Codable {
    case response(id: Int, result: RemoteControlResult, data: RemoteControlResponse?)
    case event(data: RemoteControlEvent)

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> RemoteControlMessageToClient {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(RemoteControlMessageToClient.self, from: data)
    }
}

func remoteControlHashPassword(challenge: String, salt: String, password: String) -> String {
    var concatenated = "\(password)\(salt)"
    var hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
    concatenated = "\(hash.base64EncodedString())\(challenge)"
    hash = Data(SHA256.hash(data: Data(concatenated.utf8)))
    return hash.base64EncodedString()
}
