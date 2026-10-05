import CoreMedia
import Foundation

extension Model {
    func updateInsta360VideoSources() {
        let settings = database.insta360
        videoSources.insta360 = settings.enabled ? [Camera(id: settings.id.uuidString,
                                                           name: settings.camera())] : []
    }

    func getInsta360Camera(id: UUID) -> SettingsInsta360? {
        database.insta360.id == id ? database.insta360 : nil
    }

    func getInsta360Camera(idString: String) -> SettingsInsta360? {
        database.insta360.id.uuidString == idString ? database.insta360 : nil
    }

    func reloadInsta360Client() {
        stopInsta360Client()
        updateInsta360VideoSources()
        let settings = database.insta360
        guard settings.enabled else {
            return
        }
        let client = Insta360Client(cameraId: settings.id, host: settings.host,
                                    latency: settings.latencySeconds(),
                                    softwareDecoding: database.ingestsSoftwareVideoDecoding,
                                    colorRange: stream.colorRange, delegate: self)
        ingests.insta360 = client
        client.start()
    }

    func stopInsta360Client() {
        if let client = ingests.insta360 {
            ingests.insta360 = nil
            client.stop()
            media.removeBufferedVideo(cameraId: client.cameraId)
        }
        ingests.insta360State = .disconnected
    }

    func updateInsta360IngestsSpeed(_ anyServerEnabled: inout Bool,
                                    _ speed: inout UInt64,
                                    _ total: inout UInt64,
                                    _ numberOfClients: inout Int)
    {
        guard let client = ingests.insta360 else {
            return
        }
        let stats = client.updateStats()
        speed += stats.speed
        total += stats.total
        if ingests.insta360State == .streaming {
            numberOfClients += 1
        }
        anyServerEnabled = true
    }
}

extension Model: Insta360ClientDelegate {
    nonisolated func insta360Client(_ client: Insta360Client, stateChanged state: Insta360ClientState) {
        DispatchQueue.main.async {
            guard self.ingests.insta360 === client else {
                return
            }
            if state == .streaming {
                let settings = self.database.insta360
                self.media.addBufferedVideo(cameraId: client.cameraId, name: settings.camera(),
                                            latency: settings.latencySeconds())
            } else if self.ingests.insta360State == .streaming {
                self.media.removeBufferedVideo(cameraId: client.cameraId)
            }
            self.ingests.insta360State = state
        }
    }

    nonisolated func insta360Client(_ client: Insta360Client, videoBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            guard self.ingests.insta360 === client, self.ingests.insta360State == .streaming else {
                return
            }
            self.media.appendBufferedVideoSampleBuffer(cameraId: client.cameraId, sampleBuffer: videoBuffer)
        }
    }
}
