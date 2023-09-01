//
//  Srtla.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-01.
//

import Foundation
import Network

class SrtlaType {
    private var typeName: String
    private var type: NWInterface.InterfaceType
    private var networkQueue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }
    
    init(typeName: String, type: NWInterface.InterfaceType) {
        self.typeName = typeName
        self.type = type
    }
    
    func start() {
        let options = NWProtocolUDP.Options()
        let params = NWParameters(dtls: .none, udp: options)
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

    func stop() {
    }
    
    private func viabilityDidChange(to viability: Bool) {
        print(typeName, "Connection viability changed to", viability)
    }

    private func stateDidChange(to state: NWConnection.State) {
        print(typeName, "Connection state changed to", state)
    }

    private func receive(on connection: NWConnection) {
        print(typeName, "Connection receive in state", connection.state)
    }
}

class Srtla {
    private var cellular: SrtlaType = SrtlaType(typeName: "cellular", type: .cellular)
    private var wifi: SrtlaType = SrtlaType(typeName: "wifi", type: .wifi)
    private var wiredEthernet: SrtlaType = SrtlaType(typeName: "wiredEthernet", type: .wiredEthernet)

    func start() {
        cellular.start()
        wifi.start()
        wiredEthernet.start()
    }
    
    func stop() {
        cellular.stop()
        wifi.stop()
        wiredEthernet.stop()
    }
}
