//
//  Srtla.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-01.
//

import Foundation

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
    
    func start(host: String, port: UInt16) {
        localListener.start()
        for connection in remoteConnections {
            connection.start(host: host, port: port)
        }
    }
    
    func stop() {
        for connection in remoteConnections {
            connection.stop()
        }
        localListener.stop()
    }
}
