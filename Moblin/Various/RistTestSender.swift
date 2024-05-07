import Foundation
import Rist

class RistTestSender {
    let context: RistContext
    let peer: RistPeer
    let lockQueue = DispatchQueue(label: "com.eerimoq.Moblin.ristTest")

    init?() {
        guard let context = RistContext() else {
            logger.info("rist: Failed to create context")
            return nil
        }
        self.context = context
        guard let peer = self.context.addPeer(url: "rist://192.168.50.181:7890") else {
            logger.info("rist: Failed to add peer")
            return nil
        }
        self.peer = peer
        if !self.context.start() {
            logger.info("rist: Failed to start")
            return nil
        }
        logger.info("rist: Successfully created sender")
        send()
    }

    func send() {
        lockQueue.asyncAfter(deadline: .now() + 1) {
            logger.info("rist: Sending data")
            if !self.context.send(data: Data(randomNumberOfBytes: 128)) {
                logger.info("rist: Failed to send")
            }
            self.send()
        }
    }
}
