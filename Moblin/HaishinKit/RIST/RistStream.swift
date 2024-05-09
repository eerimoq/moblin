import Foundation
import Rist

class RistStream: NetStream {
    weak var connection: RistConnection?
    private var context: RistContext?
    private var peer: RistPeer?
    private let writer = MpegTsWriter()

    init(_ connection: RistConnection) {
        super.init()
        self.connection = connection
        self.connection?.stream = self
        writer.delegate = self
    }

    deinit {
        self.connection?.stream = nil
        self.connection = nil
    }

    func start(url _: String) {
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
        writer.stopRunning()
        mixer.stopEncoding()
        peer = nil
        context = nil
    }

    func send(data: Data) {
        if context?.send(data: data) != true {
            logger.info("rist: Failed to send")
        }
    }
}

extension RistStream: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data) {
        send(data: data)
    }

    func writer(_: MpegTsWriter, doOutputPointer dataPointer: UnsafeRawBufferPointer, count: Int) {
        send(data: Data(bytes: dataPointer.baseAddress!, count: count))
    }
}
