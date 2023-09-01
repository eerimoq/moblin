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
            // print(typeName, connection)
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

class LocalListener {
    private var networkQueue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var listener: NWListener?
    var localPort: NWEndpoint.Port? = nil
    
    func start() {
        do {
            listener = try NWListener(using: .udp, on: .any)
        } catch {
            print("Failed to create SRTLA listener with error", error)
            return
        }
        listener!.stateUpdateHandler = stateDidChange(to:)
        listener!.newConnectionHandler = newConnectionHandler
        listener!.start(queue: networkQueue)
    }

    func stop() {
        if let listener = listener {
            listener.cancel()
        }
    }

    private func stateDidChange(to state: NWListener.State) {
        // print("Listener state changed to", state)
        switch state {
        case .ready:
            if let port = listener!.port {
                print("Listener at port", port)
                localPort = port
            }
        default:
            break
        }
    }
    
    func newConnectionHandler(connection: NWConnection) {
        print("New connection", connection.debugDescription)
        connection.stateUpdateHandler = { (state) in
            print("Connection state", state)
            switch state {
            case .ready:
                print("Connection ready")
            case .failed(let error):
                print("Connection failed with error", error)
            case .cancelled:
                print("Connection cancelled")
            default:
                break
            }
        }
        connection.start(queue: networkQueue)
    }
}

class Srtla {
    private var cellular = SrtlaType(typeName: "cellular", type: .cellular)
    private var wifi = SrtlaType(typeName: "wifi", type: .wifi)
    private var wiredEthernet = SrtlaType(typeName: "wiredEthernet", type: .wiredEthernet)
    private var localListener = LocalListener()
    
    func start() {
        localListener.start()
        cellular.start()
        wifi.start()
        wiredEthernet.start()
    }
    
    func stop() {
        cellular.stop()
        wifi.stop()
        wiredEthernet.stop()
        localListener.start()
    }
}
