//
//  Srtla.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-01.
//

import Foundation
import Network

class RemoteConnection {
    private var queue: DispatchQueue
    private var type: NWInterface.InterfaceType
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }
    
    init(queue: DispatchQueue, type: NWInterface.InterfaceType) {
        self.queue = queue
        self.type = type
    }
    
    func start(host: String, port: UInt16) {
        let options = NWProtocolUDP.Options()
        let params = NWParameters(dtls: .none, udp: options)
        params.requiredInterfaceType = type
        params.prohibitExpensivePaths = false
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port), using: params)
        if let connection = connection {
            connection.viabilityUpdateHandler = handleViabilityChange(to:)
            connection.stateUpdateHandler = handleStateChange(to:)
            connection.start(queue: queue)
            receivePacket()
        }
    }

    func stop() {
    }
    
    private func handleViabilityChange(to viability: Bool) {
        print("\(type): Connection viability changed to \(viability)")
    }

    private func handleStateChange(to state: NWConnection.State) {
        print("\(type): Connection state changed to \(state)")
    }

    private func receivePacket() {
        guard let connection = connection else {
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isDone, error in
            if let data = data, !data.isEmpty {
                print("\(self.type): Receive \(data)")
            }
            if let error = error {
                print("\(self.type): Receive \(error)")
                return
            }
            if isDone {
                print("\(self.type): Receive done")
                return
            }
            self.receivePacket()
        }
    }
}
