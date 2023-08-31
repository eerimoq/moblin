//
//  NetworkTest.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-31.
//

import Foundation
import Network

class NetworkTestType {
    private var typeName: String
    private var type: NWInterface.InterfaceType
    
    init(typeName: String, type: NWInterface.InterfaceType) {
        self.typeName = typeName
        self.type = type
    }
    
    private var networkQueue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }

    func connect() {
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: .init(), tcp: tcpOptions)
        params.requiredInterfaceType = type
        params.prohibitExpensivePaths = false
        connection = NWConnection(host: "mys-lang.org", port: 443, using: params)
        if let connection = connection {
            print(typeName, connection)
            connection.viabilityUpdateHandler = viabilityDidChange(to:)
            connection.stateUpdateHandler = stateDidChange(to:)
            connection.start(queue: networkQueue)
            receive(on: connection)
        }
    }

    private func viabilityDidChange(to viability: Bool) {
        print(typeName, "Connection viability changed to ", viability)
    }

    private func stateDidChange(to state: NWConnection.State) {
        print(typeName, "Connection:", state)
    }

    private func receive(on connection: NWConnection) {
        print(typeName, "Receive", connection.state)
    }
}

class NetworkTest {
    private var cellular: NetworkTestType = NetworkTestType(typeName: "cellular", type: .cellular)
    private var wifi: NetworkTestType = NetworkTestType(typeName: "wifi", type: .wifi)
    private var wiredEthernet: NetworkTestType = NetworkTestType(typeName: "wiredEthernet", type: .wiredEthernet)

    func connect() {
        cellular.connect()
        wifi.connect()
        wiredEthernet.connect()
    }
}
