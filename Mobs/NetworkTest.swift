//
//  NetworkTest.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-31.
//

import Foundation
import Network

class NetworkTestCellular {
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
        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi]
        connection = NWConnection(host: "mys-lang.org", port: 443, using: params)
        print("cellular", connection!)
        connection?.viabilityUpdateHandler = viabilityDidChange(to:)
        connection?.stateUpdateHandler = stateDidChange(to:)
        connection?.start(queue: networkQueue)
        if let connection = connection {
            receive(on: connection)
        }
    }

    private func viabilityDidChange(to viability: Bool) {
        print("Cellular Connection viability changed to ", viability)
    }

    private func stateDidChange(to state: NWConnection.State) {
        print("Cellular Connection:", state)
    }

    private func receive(on connection: NWConnection) {
        print("Cellular Receive", connection.state)
    }
}

class NetworkTestWiFi {
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
        params.requiredInterfaceType = .wifi
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.cellular]
        connection = NWConnection(host: "mys-lang.org", port: 443, using: params)
        print("wifi", connection!)
        connection?.viabilityUpdateHandler = viabilityDidChange(to:)
        connection?.stateUpdateHandler = stateDidChange(to:)
        connection?.start(queue: networkQueue)
        if let connection = connection {
            receive(on: connection)
        }
    }

    private func viabilityDidChange(to viability: Bool) {
        print("wifi Connection viability changed to ", viability)
    }

    private func stateDidChange(to state: NWConnection.State) {
        print("wifi Connection:", state)
    }

    private func receive(on connection: NWConnection) {
        print("wifi Receive", connection.state)
    }
}

class NetworkTest {
    private var cellular: NetworkTestCellular = NetworkTestCellular()
    private var wifi: NetworkTestWiFi = NetworkTestWiFi()

    func connectUsingCellularAndWifi() {
        cellular.connect()
        wifi.connect()
    }
}
