//
//  Srtla.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-01.
//

import Foundation
import Network

class RemoteConnection {
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
            connection.viabilityUpdateHandler = handleViabilityChange(to:)
            connection.stateUpdateHandler = handleStateChange(to:)
            connection.start(queue: networkQueue)
            receive(on: connection)
        }
    }

    func stop() {
    }
    
    private func handleViabilityChange(to viability: Bool) {
        print(typeName, "Connection viability changed to", viability)
    }

    private func handleStateChange(to state: NWConnection.State) {
        print(typeName, "Connection state changed to", state)
    }

    private func receive(on connection: NWConnection) {
        print(typeName, "Connection receive in state", connection.state)
    }
}

class Srtla {
    private var networkQueue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var remoteConnections: [RemoteConnection] = [
        RemoteConnection(typeName: "cellular", type: .cellular),
        RemoteConnection(typeName: "wifi", type: .wifi),
        RemoteConnection(typeName: "wiredEthernet", type: .wiredEthernet)
    ]
    private var listener: NWListener?
    var listenerPort: UInt16 = 0
    
    func start() {
        startListener()
        for connection in remoteConnections {
            connection.start()
        }
    }
    
    func stop() {
        for connection in remoteConnections {
            connection.stop()
        }
        stopListener()
    }
    
    func startListener() {
        do {
            listener = try NWListener(using: .udp, on: .any)
        } catch {
            print("Failed to create SRTLA listener with error", error)
            return
        }
        listener!.stateUpdateHandler = handleListenerStateChange(to:)
        listener!.newConnectionHandler = handleNewListenerConnection(connection:)
        listener!.start(queue: networkQueue)
    }

    func stopListener() {
        if let listener = listener {
            listener.cancel()
        }
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        switch state {
        case .setup:
            break
        case .ready:
            if let port = listener!.port {
                listenerPort = port.rawValue
                print("Listener at port", listenerPort)
            }
        default:
            print("Ignoring listener state changed to", state)
            break
        }
    }
    
    func handleNewListenerConnection(connection: NWConnection) {
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
