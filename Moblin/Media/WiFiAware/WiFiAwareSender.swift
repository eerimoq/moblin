import Foundation
import Network
import WiFiAware

@available(iOS 26, *)
private struct Receiver {
    let connection: NetworkConnection<UDP>
    let senderTask: Task<Void, Never>
    let receiverTask: Task<Void, Never>
}

@available(iOS 26, *)
actor WiFiAwareSender {
    static let shared = WiFiAwareSender()
    private var connections: [WAPairedDevice.ID: Receiver] = [:]

    func browse() async throws {
        logger.info("wifi-aware-sender: Start")
        let browser = NetworkBrowser(for:
            .wifiAware(.connecting(to: .allPairedDevices, from: wiFiAwareSubscribableService())))
            .onStateUpdate { _, state in
                logger.info("wifi-aware-sender: State changed to: \(state)")
            }
        try? await browser.run { endpoints in
            logger.info("wifi-aware-sender: Discovered: \(endpoints)")
            for endpoint in endpoints {
                self.connections[endpoint.device.id]?.senderTask.cancel()
                self.connections[endpoint.device.id]?.receiverTask.cancel()
                let connection = NetworkConnection(to: endpoint, using: .parameters {
                    UDP()
                }
                .wifiAware { $0.performanceMode = .realtime }
                .serviceClass(.interactiveVideo))
                connection.onStateUpdate { _, state in
                    logger.info("wifi-aware-sender: Connection state changed to: \(state)")
                }
                let senderTask = Task {
                    logger.info("wifi-aware-sender: Sender task started")
                    do {
                        while true {
                            logger.info("wifi-aware-sender: Sending data")
                            try await connection.send(Data([1, 2, 3, 4]))
                            try await sleep(seconds: 5)
                        }
                    } catch {
                        logger.info("wifi-aware-sender: Sender task error: \(error)")
                    }
                    if connection === self.connections[endpoint.device.id]?.connection {
                        logger.info("wifi-aware-sender: Removing connection")
                        self.connections[endpoint.device.id]?.senderTask.cancel()
                        self.connections[endpoint.device.id]?.receiverTask.cancel()
                        self.connections.removeValue(forKey: endpoint.device.id)
                    }
                    logger.info("wifi-aware-sender: Sender task stopped")
                }
                let receiverTask = Task {
                    logger.info("wifi-aware-sender: Receiver task started")
                    while let data = try? await connection.receive(), !data.content.isEmpty {
                        logger.info("wifi-aware-sender: Got data: \(data.content.hexString())")
                    }
                    logger.info("wifi-aware-sender: Receiver task stopped")
                }
                self.connections[endpoint.device.id] = Receiver(connection: connection,
                                                                senderTask: senderTask,
                                                                receiverTask: receiverTask)
            }
            logger.info("wifi-aware-sender: Number of connections: \(self.connections.count)")
        }
        for connection in connections.values {
            connection.senderTask.cancel()
            connection.receiverTask.cancel()
        }
        connections.removeAll()
        logger.info("wifi-aware-sender: Stop")
    }
}
