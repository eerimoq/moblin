//
//  LocalListener.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-01.
//

import Foundation
import Network

class LocalListener {
    private var queue: DispatchQueue
    private var listener: NWListener?
    var port: UInt16? = nil
    var packetHandler: ((_ packet: Data) -> Void)?
    private var connection: NWConnection?
    
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
                print("Listener ready at port", self.port!)
            }
        default:
            self.port = nil
        }
    }
    
    func handleNewListenerConnection(connection: NWConnection) {
        self.connection = connection
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
        receivePacket()
    }
    
    private func receivePacket() {
        guard let connection = connection else {
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isDone, error in
            if let data = data, !data.isEmpty {
                if let packetHandler = self.packetHandler {
                    packetHandler(data)
                } else {
                    print("Discarding local packet.")
                }
            }
            if let error = error {
                print("Local error:", error)
                return
            }
            if isDone {
                print("Local done")
                return
            }
            self.receivePacket()
        }
    }
    
    func sendPacket(packet: Data) {
        guard let connection = connection else {
            return
        }
        connection.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("Local send error: \(error)")
            }
        })
    }
}
