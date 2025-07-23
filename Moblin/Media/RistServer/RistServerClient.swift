import Foundation
import Rist

class RistServerClient {
    private let context: RistReceiverContext

    init?(inputUrl: String) {
        guard let context = RistReceiverContext(inputUrl: inputUrl) else {
            logger.info("xxx failed to create context")
            return nil
        }
        self.context = context
        context.delegate = self
    }

    func start() {
        _ = context.start()
    }
}

extension RistServerClient: RistReceiverContextDelegate {
    func ristReceiverContextConnected(_: Rist.RistReceiverContext) {
        logger.info("xxx rist-server-client: Connected")
    }

    func ristReceiverContextDisconnected(_: Rist.RistReceiverContext) {
        logger.info("xxx rist-server-client: Disconnected")
    }

    func ristReceiverContextReceivedData(_: Rist.RistReceiverContext, data _: Data) {
        // logger.info("xxx rist-server-client: data \(data)")
    }
}
