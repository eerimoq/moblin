import Network
import WiFiAware

@available(iOS 26, *)
private struct Sender {
    // periphery:ignore
    let connection: NetworkConnection<UDP>
    let task: Task<Void, Never>
}

@available(iOS 26, *)
actor WiFiAwareReceiver {
    static let shared = WiFiAwareReceiver()
    private var connections: [Sender] = []

    func listen() async throws {
        logger.info("wifi-aware-receiver: Start")
        let listener = try NetworkListener(for:
            .wifiAware(.connecting(to: wiFiAwarePublishableService(), from: .allPairedDevices)),
            using: .parameters {
                UDP()
            }
            .wifiAware { $0.performanceMode = .realtime }
            .serviceClass(.interactiveVideo))
        listener.onStateUpdate { _, state in
            logger.info("wifi-aware-receiver: State changed to: \(state)")
        }
        try? await listener.run { connection in
            logger.info("wifi-aware-receiver: Received connection: \(connection)")
            let task = Task {
                while let data = try? await connection.receive(), !data.content.isEmpty {
                    logger.info("wifi-aware-receiver: Got data: \(data.content.hexString())")
                    try? await connection.send(data.content)
                }
            }
            self.connections.append(Sender(connection: connection, task: task))
        }
        for connection in connections {
            connection.task.cancel()
        }
        connections.removeAll()
        logger.info("wifi-aware-receiver: Stop")
    }
}
