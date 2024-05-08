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
        writer.expectedMedias.insert(.video)
        writer.expectedMedias.insert(.audio)
        mixer.startEncoding(writer)
        mixer.startRunning()
        writer.startRunning()
    }

    func stop() {
        logger.info("rist: Should stop stream")
    }

    func send(data: Data) {
        if context?.send(data: data) != true {
            logger.info("rist: Failed to send")
        }
    }
}

extension RistStream: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data) {
        // logger.info("rist: Got mpegts data")
        send(data: data)
    }

    func writer(_: MpegTsWriter, doOutputPointer dataPointer: UnsafeRawBufferPointer, count: Int) {
        // logger.info("rist: Got mpegts data pointer")
        send(data: Data(bytes: dataPointer.baseAddress!, count: count))
    }
}
