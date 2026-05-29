@testable import Moblin
import Network
import Testing

struct WebNetworkRouteSelectorSuite {
    @Test
    func cellularIsPreferredOverWifi() {
        let selector = WebNetworkRouteSelector()
        selector.setRoutes(directInterfaceTypes: [.wifi, .cellular], moblinkRelays: [])

        #expect(selector.nextRoute() == .direct(.cellular))
    }

    @Test
    func directMultipathIsPreferredWhenSupported() {
        let selector = WebNetworkRouteSelector(directMultipath: true)
        selector.setRoutes(directInterfaceTypes: [.wifi, .cellular], moblinkRelays: [])

        #expect(selector.nextRoute() == .directMultipath)
    }

    @Test
    func moblinkIsPreferredOverWifiAfterCellularFails() {
        let selector = WebNetworkRouteSelector()
        let relayId = UUID()
        let now = Date()
        selector.setRoutes(directInterfaceTypes: [.wifi, .cellular],
                           moblinkRelays: [.init(id: relayId, name: "Relay")])

        selector.connectionStarted(route: .direct(.cellular))
        selector.connectionFinished(route: .direct(.cellular), success: false, now: now)

        #expect(selector.nextRoute(now: now) == .moblink(relayId))
    }

    @Test
    func concurrentConnectionsUseHealthyRoutes() {
        let selector = WebNetworkRouteSelector()
        let relayId = UUID()
        selector.setRoutes(directInterfaceTypes: [.wifi, .cellular],
                           moblinkRelays: [.init(id: relayId, name: "Relay")])

        let firstRoute = selector.nextRoute()
        #expect(firstRoute == .direct(.cellular))
        if let firstRoute {
            selector.connectionStarted(route: firstRoute)
        }

        #expect(selector.nextRoute() == .moblink(relayId))
    }

    @Test
    func failedRouteRecoversAfterCooldown() {
        let selector = WebNetworkRouteSelector(failureCooldown: 10)
        let now = Date()
        selector.setRoutes(directInterfaceTypes: [.wifi, .cellular], moblinkRelays: [])

        selector.connectionStarted(route: .direct(.cellular))
        selector.connectionFinished(route: .direct(.cellular), success: false, now: now)

        #expect(selector.nextRoute(now: now) == .direct(.wifi))
        #expect(selector.nextRoute(now: now.addingTimeInterval(10)) == .direct(.cellular))
    }
}
