//
//  LocalListener.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-01.
//

import Foundation
import Network

class LocalListener {
    private var listener: NWListener?
    private var queue: DispatchQueue
    var port: UInt16 = 0
    
    init(queue: DispatchQueue) {
        self.queue = queue
    }
    
    func start() {
        do {
            let options = NWProtocolUDP.Options()
            let parameters = NWParameters(dtls: .none, udp: options)
            parameters.acceptLocalOnly = true
            listener = try NWListener(using: parameters)
        } catch {
            print("Failed to create SRTLA listener with error", error)
            return
        }
        listener!.stateUpdateHandler = handleListenerStateChange(to:)
        listener!.newConnectionHandler = handleNewListenerConnection(connection:)
        listener!.start(queue: queue)
    }

    func stop() {
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
                self.port = port.rawValue
                print("Listener at port", self.port)
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
        connection.start(queue: queue)
    }
}
