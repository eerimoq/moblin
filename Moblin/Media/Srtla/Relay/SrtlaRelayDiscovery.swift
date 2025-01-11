//
//  SrtlaRelayDiscovery.swift
//  Moblin
//
//  Created by Erik Moqvist on 2025-01-11.
//

// let browser = NWBrowser(for: .bonjour(type: "_moblink._tcp", domain: "local"), using: .applicationService)
// browser.stateUpdateHandler = { newState in
//     logger.info("xxx network browser state \(newState)")
//     for result in browser.browseResults {
//         logger.info("xxx result \(result) \(result.endpoint)")
//     }
// }
// browser.start(queue: .main)

// let parameters = NWParameters(dtls: .none, udp: NWProtocolUDP.Options())
// parameters.requiredLocalEndpoint = .hostPort(
//     host: .name("", nil),
//     port: NWEndpoint.Port(rawValue: port)!
// )
// bonjourListener = try NWListener(service: .init(type: "_moblink._udp"), using: parameters)
// bonjourListener?.start(queue: srtlaRelayServerQueue)
