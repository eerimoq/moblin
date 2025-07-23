import Foundation
import Rist

class RistServer {
    private var clients: [RistServerClient] = []

    init(inputUrls: [String]) {
        for inputUrl in inputUrls {
            if let client = RistServerClient(inputUrl: inputUrl) {
                clients.append(client)
            } else {
                logger.info("xxx failed to create context")
            }
        }
    }

    func start() {
        logger.info("xxx starting")
        for client in clients {
            client.start()
        }
    }

    func stop() {}
}
