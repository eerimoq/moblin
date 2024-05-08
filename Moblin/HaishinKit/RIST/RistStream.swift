import Foundation
import Rist

private let ristQueue = DispatchQueue(label: "com.eerimoq.Moblin.rist")

class RistStream: NetStream {
    weak var connection: RistConnection?
    private var context: RistContext?
    private var peer: RistPeer?

    private lazy var writer: MpegTsWriter = {
        var writer = MpegTsWriter()
        writer.delegate = self
        return writer
    }()

    init(_ connection: RistConnection) {
        super.init()
        self.connection = connection
        self.connection?.stream = self
    }

    func start(url: String) {
        logger.info("rist: Should start stream with URL \(url)")
        guard let context = RistContext() else {
            logger.info("rist: Failed to create context")
            return
        }
        self.context = context
        guard let peer = context.addPeer(url: "rist://192.168.50.181:2030?aes-type=128&secret=xyz")
        else {
            logger.info("rist: Failed to add peer")
            return
        }
        self.peer = peer
        if !context.start() {
            logger.info("rist: Failed to start")
            return
        }
        logger.info("rist: Successfully created sender")
        send()
    }

    func stop() {
        logger.info("rist: Should stop stream")
    }

    func send() {
        ristQueue.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else {
                logger.info("rist: Stop sending")
                return
            }
            logger.info("rist: Sending data")
            if self.context?.send(data: Data(randomNumberOfBytes: 128)) != true {
                logger.info("rist: Failed to send")
            }
            self.send()
        }
    }
}

extension RistStream: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput _: Data) {
        logger.info("rist: Got mpegts data")
    }

    func writer(_: MpegTsWriter, doOutputPointer _: UnsafeRawBufferPointer, count _: Int) {
        logger.info("rist: Got mpegts data pointer")
    }
}
