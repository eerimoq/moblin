import CoreMedia
import Foundation

extension Model {
    func stopRistServer() {
        servers.rist?.stop()
        servers.rist = nil
    }

    func reloadRistServer() {
        stopRistServer()
        if database.ristServer.enabled {
            servers.rist = RistServer(inputUrls: database.ristServer.streams.map { "rist://@0.0.0.0:\($0.port)" })
            servers.rist?.start()
        }
    }

    func ristServerEnabled() -> Bool {
        return database.ristServer.enabled
    }

    func ristCameras() -> [(UUID, String)] {
        return database.ristServer.streams.map { stream in
            (stream.id, stream.camera())
        }
    }

    func getRistStream(id: UUID) -> SettingsRistServerStream? {
        return database.ristServer.streams.first { stream in
            stream.id == id
        }
    }

    func getRistStream(idString: String) -> SettingsRistServerStream? {
        return database.ristServer.streams.first { stream in
            idString == stream.id.uuidString
        }
    }

    func isRistStreamConnected(port _: UInt16) -> Bool {
        return true
    }
}
