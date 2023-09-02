//
//  Srtla.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-01.
//

import Foundation
import Network

class Srtla {
    private var queue = DispatchQueue(label: "com.eerimoq.network", qos: .userInitiated)
    private var remoteConnections: [RemoteConnection] = []
    private var localListener: LocalListener
    
    init() {
        localListener = LocalListener(queue: queue)
        remoteConnections.append(RemoteConnection(queue: queue, type: .cellular))
        remoteConnections.append(RemoteConnection(queue: queue, type: .wifi))
        remoteConnections.append(RemoteConnection(queue: queue, type: .wiredEthernet))
    }
    
    func localPort() -> UInt16? {
        return localListener.port
    }
    
    func start(uri: String) {
        guard
            let url = URL(string: uri),
            let host = url.host,
            let port = url.port else {
            print("Failed to start srtla")
            return
        }
        localListener.packetHandler = handleLocalPacket(packet:)
        localListener.start()
        for connection in remoteConnections {
            connection.packetHandler = handleRemotePacket(packet:)
            connection.start(host: host, port: UInt16(port))
        }
    }
    
    func stop() {
        for connection in remoteConnections {
            connection.stop()
        }
        localListener.stop()
    }
    
    func handleLocalPacket(packet: Data) {
        // print("Got local packet:", packet)
        guard let connection = findBestRemoteConnection() else {
            print("No remote connection found. Discarding packet.")
            return
        }
        connection.sendPacket(packet: packet)
    }
    
    func handleRemotePacket(packet: Data) {
        // print("Got remote packet:", packet)
        localListener.sendPacket(packet: packet)
    }
    
    func findBestRemoteConnection() -> RemoteConnection? {
        var bestConnection = remoteConnections[0]
        for connection in remoteConnections {
            if connection.score() > bestConnection.score() {
                bestConnection = connection
            }
        }
        return bestConnection.score() == -1 ? nil : bestConnection
    }
}
