import Foundation
import Network

extension NWPath {
    // The list contains duplicates since iOS 26. Apple bug?
    func uniqueAvailableInterfaces() -> [NWInterface] {
        var interfaces: [NWInterface] = []
        for interface in availableInterfaces where !interfaces.contains(interface) {
            interfaces.append(interface)
        }
        return interfaces
    }
}

extension NWEndpoint.Port {
    init(integer: Int) {
        self.init(integerLiteral: UInt16(clamping: integer))
    }
}

final class NWConnectionWithId: Hashable, Equatable {
    let id: String
    let connection: NWConnection

    init(connection: NWConnection) {
        self.connection = connection
        id = UUID().uuidString
    }

    static func == (lhs: NWConnectionWithId, rhs: NWConnectionWithId) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension NWConnection.ContentContext {
    func webSocketOperation() -> NWProtocolWebSocket.Opcode? {
        let definitions = protocolMetadata(definition: NWProtocolWebSocket.definition) as? Network.NWProtocolWebSocket
            .Metadata
        return definitions?.opcode
    }
}

extension NWConnection {
    func sendWebSocket(data: Data?, opcode: NWProtocolWebSocket.Opcode) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: opcode)
        let context = NWConnection.ContentContext(identifier: "context", metadata: [metadata])
        send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }
}
