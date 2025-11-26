import Foundation
import Network

class Moblink: ObservableObject {
    var streamer: MoblinkStreamer?
    var relays: [MoblinkRelay] = []
    var scanner: MoblinkScanner?
    var relayState: MoblinkRelayState = .waitingForStreamers
    @Published var streamerOk = true
    @Published var status = noValue
    @Published var scannerDiscoveredStreamers: [MoblinkScannerStreamer] = []
}

extension Model {
    func stopMoblinkStreamer() {
        moblink.streamer?.stop()
        moblink.streamer = nil
    }

    func reloadMoblinkStreamer() {
        stopMoblinkStreamer()
        if isMoblinkStreamerConfigured() {
            moblink.streamer = MoblinkStreamer(
                port: database.moblink.streamer.port,
                password: database.moblink.password
            )
            moblink.streamer?.start(delegate: self)
        }
    }

    func isMoblinkStreamerConfigured() -> Bool {
        let server = database.moblink.streamer
        return server.enabled && server.port > 0 && !database.moblink.password.isEmpty
    }

    func reloadMoblinkRelay() {
        stopMoblinkRelay()
        stopMoblinkScanner()
        if isMoblinkRelayConfigured() {
            reloadMoblinkScanner()
            if database.moblink.relay.manual {
                startMoblinkRelayManual()
            } else {
                startMoblinkRelayAutomatic()
            }
        }
    }

    private func startMoblinkRelayManual() {
        guard let streamerUrl = URL(string: database.moblink.relay.url) else {
            return
        }
        addMoblinkRelay(streamerUrl: streamerUrl)
    }

    private func startMoblinkRelayAutomatic() {
        for streamer in moblink.scannerDiscoveredStreamers {
            guard let url = streamer.urls.first, let streamerUrl = URL(string: url) else {
                return
            }
            addMoblinkRelay(streamerUrl: streamerUrl)
        }
    }

    private func addMoblinkRelay(streamerUrl: URL) {
        guard !moblink.relays.contains(where: { $0.streamerUrl == streamerUrl }) else {
            return
        }
        guard !isMoblinkRelayOnThisDevice(streamerUrl: streamerUrl) else {
            logger.info("Not adding Moblink relay to ourselves: \(streamerUrl)")
            return
        }
        let relay = MoblinkRelay(
            name: database.moblink.relay.name,
            streamerUrl: streamerUrl,
            password: database.moblink.password,
            delegate: self
        )
        relay.start()
        moblink.relays.append(relay)
    }

    func isMoblinkRelayConfigured() -> Bool {
        let client = database.moblink.relay
        if !client.enabled {
            return false
        }
        if client.manual {
            return !client.url.isEmpty && !database.moblink.password.isEmpty
        } else {
            return true
        }
    }

    func areMoblinkRelaysOk() -> Bool {
        return moblink.relayState == .connected || moblink.relayState == .waitingForStreamers
    }

    func moblinkIpStatusesUpdated() {
        var toRemove: IndexSet = []
        for (index, relay) in moblink.relays.enumerated()
            where isMoblinkRelayOnThisDevice(streamerUrl: relay.streamerUrl)
        {
            logger.info("Removing Moblink relay as it is connected to ourselves.")
            relay.stop()
            toRemove.insert(index)
        }
        moblink.relays.remove(atOffsets: toRemove)
    }

    private func isMoblinkRelayOnThisDevice(streamerUrl: URL) -> Bool {
        let host = streamerUrl.host()
        return statusOther.ipStatuses.contains(where: { $0.ipType.formatAddress($0.ip) == host })
    }

    func stopMoblinkRelay() {
        for relay in moblink.relays {
            relay.stop()
        }
        moblink.relays.removeAll()
        stopMoblinkScanner()
    }

    func reloadMoblinkScanner() {
        stopMoblinkScanner()
        moblink.scanner = MoblinkScanner(delegate: self)
        moblink.scanner?.start()
    }

    func stopMoblinkScanner() {
        moblink.scanner?.stop()
        moblink.scanner = nil
        moblink.scannerDiscoveredStreamers.removeAll()
    }

    func updateMoblinkStatus() {
        var status: String
        var serverOk = true
        if isMoblinkRelayConfigured(), isMoblinkStreamerConfigured() {
            let (serverStatus, ok) = moblinkStreamerStatus()
            status = "\(serverStatus), \(moblink.relayState.rawValue)"
            serverOk = ok
        } else if isMoblinkRelayConfigured() {
            status = moblink.relayState.rawValue
        } else if isMoblinkStreamerConfigured() {
            let (serverStatus, ok) = moblinkStreamerStatus()
            status = serverStatus
            serverOk = ok
        } else {
            status = noValue
        }
        if status != moblink.status {
            moblink.status = status
        }
        if serverOk != moblink.streamerOk {
            moblink.streamerOk = serverOk
        }
    }

    private func moblinkStreamerStatus() -> (String, Bool) {
        guard let streamer = moblink.streamer else {
            return ("", true)
        }
        var statuses: [String] = []
        var ok = true
        for (name, batteryPercentage, thermalState) in streamer.getStatuses() {
            let (status, deviceOk) = formatDeviceStatus(name: name,
                                                        batteryPercentage: batteryPercentage,
                                                        thermalState: thermalState)
            if !deviceOk {
                ok = false
            }
            statuses.append(status)
        }
        return (statuses.joined(separator: ", "), ok)
    }
}

extension Model: MoblinkStreamerDelegate {
    func moblinkStreamerTunnelAdded(endpoint: Network.NWEndpoint, relayId: UUID, relayName: String) {
        let connectionPriorities = stream.srt.connectionPriorities
        if let priority = connectionPriorities.priorities.first(where: { $0.relayId == relayId }) {
            priority.name = relayName
        } else {
            let priority = SettingsStreamSrtConnectionPriority(name: relayName)
            priority.relayId = relayId
            connectionPriorities.priorities.append(priority)
        }
        media.addMoblink(endpoint: endpoint, id: relayId, name: relayName)
    }

    func moblinkStreamerTunnelRemoved(endpoint: Network.NWEndpoint) {
        media.removeMoblink(endpoint: endpoint)
    }
}

extension Model: MoblinkRelayDelegate {
    func moblinkRelayNewState(state: MoblinkRelayState) {
        moblink.relayState = state
    }

    func moblinkRelayGetStatus() -> (Int?, MoblinkThermalState?) {
        let thermalState: MoblinkThermalState?
        switch statusOther.thermalState {
        case .nominal, .fair:
            thermalState = .white
        case .serious:
            thermalState = .yellow
        case .critical:
            thermalState = .red
        @unknown default:
            thermalState = nil
        }
        return (Int(100 * battery.level), thermalState)
    }
}

extension Model: MoblinkScannerDelegate {
    func moblinkScannerDiscoveredStreamers(streamers: [MoblinkScannerStreamer]) {
        moblink.scannerDiscoveredStreamers = streamers
        if !database.moblink.relay.manual {
            startMoblinkRelayAutomatic()
        }
    }
}
