//
//  RemoteConnection.swift
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
            receive(on: connection)
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

    private func receive(on connection: NWConnection) {
        print("\(type): Connection receive in state \(connection.state)")
    }
}
