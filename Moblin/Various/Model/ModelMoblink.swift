import Foundation
import Network

extension Model {
    func stopMoblinkStreamer() {
        moblinkStreamer?.stop()
        moblinkStreamer = nil
    }

    func reloadMoblinkStreamer() {
        stopMoblinkStreamer()
        if isMoblinkStreamerConfigured() {
            moblinkStreamer = MoblinkStreamer(
                port: database.moblink.server.port,
                password: database.moblink.password
            )
            moblinkStreamer?.start(delegate: self)
        }
    }

    func isMoblinkStreamerConfigured() -> Bool {
        let server = database.moblink.server
        return server.enabled && server.port > 0 && !database.moblink.password.isEmpty
    }

    func reloadMoblinkRelay() {
        stopMoblinkRelay()
        stopMoblinkScanner()
        if isMoblinkRelayConfigured() {
            reloadMoblinkScanner()
            if database.moblink.client.manual {
                startMoblinkRelayManual()
            } else {
                startMoblinkRelayAutomatic()
            }
        }
    }

    private func startMoblinkRelayManual() {
        guard let streamerUrl = URL(string: database.moblink.client.url) else {
            return
        }
        addMoblinkRelay(streamerUrl: streamerUrl)
    }

    private func startMoblinkRelayAutomatic() {
        for streamer in moblinkScannerDiscoveredStreamers {
            guard let url = streamer.urls.first, let streamerUrl = URL(string: url) else {
                return
            }
            addMoblinkRelay(streamerUrl: streamerUrl)
        }
    }

    private func addMoblinkRelay(streamerUrl: URL) {
        guard !moblinkRelays.contains(where: { $0.streamerUrl == streamerUrl }) else {
            return
        }
        guard !isMoblinkRelayOnThisDevice(streamerUrl: streamerUrl) else {
            return
        }
        logger.info("xxx relay \(streamerUrl)")
        let relay = MoblinkRelay(
            name: database.moblink.client.name,
            streamerUrl: streamerUrl,
            password: database.moblink.password,
            delegate: self
        )
        relay.start()
        moblinkRelays.append(relay)
    }

    func isMoblinkRelayConfigured() -> Bool {
        let client = database.moblink.client
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
        return moblinkRelayState == .connected || moblinkRelayState == .waitingForStreamers
    }

    func moblinkIpStatusesUpdated() {
        logger.info("xxx statuses")
        for status in ipStatuses {
            logger.info("xxx   status \(status)")
        }
    }

    private func isMoblinkRelayOnThisDevice(streamerUrl: URL) -> Bool {
        logger.info("xxx is on this device \(streamerUrl)")
        return false
    }

    func stopMoblinkRelay() {
        for relay in moblinkRelays {
            relay.stop()
        }
        moblinkRelays.removeAll()
        stopMoblinkScanner()
    }

    func reloadMoblinkScanner() {
        stopMoblinkScanner()
        moblinkScanner = MoblinkScanner(delegate: self)
        moblinkScanner?.start()
    }

    func stopMoblinkScanner() {
        moblinkScanner?.stop()
        moblinkScanner = nil
        moblinkScannerDiscoveredStreamers.removeAll()
    }

    func updateMoblinkStatus() {
        var status: String
        var serverOk = true
        if isMoblinkRelayConfigured(), isMoblinkStreamerConfigured() {
            let (serverStatus, ok) = moblinkStreamerStatus()
            status = "\(serverStatus), \(moblinkRelayState.rawValue)"
            serverOk = ok
        } else if isMoblinkRelayConfigured() {
            status = moblinkRelayState.rawValue
        } else if isMoblinkStreamerConfigured() {
            let (serverStatus, ok) = moblinkStreamerStatus()
            status = serverStatus
            serverOk = ok
        } else {
            status = noValue
        }
        if status != moblinkStatus {
            moblinkStatus = status
        }
        if serverOk != moblinkStreamerOk {
            moblinkStreamerOk = serverOk
        }
    }

    private func moblinkStreamerStatus() -> (String, Bool) {
        guard let moblinkStreamer else {
            return ("", true)
        }
        var statuses: [String] = []
        var ok = true
        for (name, batteryPercentage) in moblinkStreamer.getStatuses() {
            let (status, deviceOk) = formatDeviceStatus(name: name, batteryPercentage: batteryPercentage)
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
        let connectionPriorities = stream.srt.connectionPriorities!
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
        moblinkRelayState = state
    }

    func moblinkRelayGetBatteryPercentage() -> Int {
        return Int(100 * batteryLevel)
    }
}

extension Model: MoblinkScannerDelegate {
    func moblinkScannerDiscoveredStreamers(streamers: [MoblinkScannerStreamer]) {
        logger.info("xxx xxx \(streamers)")
        moblinkScannerDiscoveredStreamers = streamers
        if !database.moblink.client.manual {
            startMoblinkRelayAutomatic()
        }
    }
}
