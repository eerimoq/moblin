import Foundation
import Rist

class RistStream: NetStream {
    weak var connection: RistConnection?
    private var context: RistContext?
    private var peers: [RistPeer] = []
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

    func start(url: String, bonding: Bool) {
        guard let context = RistContext() else {
            logger.info("rist: Failed to create context")
            return
        }
        self.context = context
        if bonding {
            // To Do: Monitor available network inferfaces
            // addPeer(url: "\(url)&miface=en0")
            // addPeer(url: "\(url)&miface=pdp_ip0")
            addPeer(url: "\(url)&miface=en0&weight=1")
            addPeer(url: "\(url)&miface=pdp_ip0&weight=1")
        } else {
            addPeer(url: url)
        }
        guard !peers.isEmpty else {
            return
        }
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

    func addPeer(url: String) {
        guard let peer = context?.addPeer(url: url) else {
            logger.info("rist: Failed to add peer")
            return
        }
        peers.append(peer)
    }

    func stop() {
        writer.stopRunning()
        mixer.stopEncoding()
        peers.removeAll()
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
