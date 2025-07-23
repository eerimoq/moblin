import AVFoundation
import Foundation
import Rist

protocol RistServerDelegate: AnyObject {
    func ristServerOnConnected(port: UInt16)
    func ristServerOnDisconnected(port: UInt16, reason: String)
    func ristServerOnVideoBuffer(port: UInt16, _ sampleBuffer: CMSampleBuffer)
    func ristServerOnAudioBuffer(port: UInt16, _ sampleBuffer: CMSampleBuffer)
    func ristServerSetTargetLatencies(
        port: UInt16,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

let ristServerQueue = DispatchQueue(label: "com.eerimoq.rist-server")

class RistServer {
    private var clients: [RistServerClient] = []
    weak var delegate: (any RistServerDelegate)?
    private let inputUrls: [String]

    init(inputUrls: [String]) {
        self.inputUrls = inputUrls
    }

    func start() {
        ristServerQueue.async {
            self.startInner()
        }
    }

    func stop() {
        logger.info("rist-server: Stopping")
    }

    private func startInner() {
        logger.info("rist-server: Starting")
        for inputUrl in inputUrls {
            if let client = RistServerClient(inputUrl: inputUrl, timecodesEnabled: false) {
                client.server = self
                client.start()
                clients.append(client)
            } else {
                logger.info("rist-server: Failed to create client for URL: \(inputUrl)")
            }
        }
    }
}
