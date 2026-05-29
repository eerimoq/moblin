import Foundation
import Network

enum WebNetworkRoute: Equatable {
    case directMultipath
    case direct(NWInterface.InterfaceType)
    case moblink(UUID)
}

struct WebNetworkMoblinkRelay: Equatable {
    let id: UUID
    let name: String
}

protocol WebNetworkMoblinkConnectionDelegate: AnyObject {
    func webNetworkMoblinkConnectionReceiveData(data: Data)
    func webNetworkMoblinkConnectionClosed()
}

protocol WebNetworkMoblinkConnection: AnyObject {
    func send(data: Data)
    func close()
}

protocol WebNetworkMoblinkRelayConnector: AnyObject {
    func openWebProxyConnection(
        relayId: UUID,
        host: String,
        port: UInt16,
        delegate: any WebNetworkMoblinkConnectionDelegate,
        completion: @escaping ((any WebNetworkMoblinkConnection)?) -> Void
    )
}

private struct WebNetworkRouteState {
    var route: WebNetworkRoute
    var activeConnectionCount: Int = 0
    var failureCount: Int = 0
    var lastFailureTime: Date?
}

final class WebNetworkRouteSelector {
    private var routes: [WebNetworkRouteState] = []
    private let failureCooldown: TimeInterval
    private let directMultipath: Bool

    init(failureCooldown: TimeInterval = 10, directMultipath: Bool = false) {
        self.failureCooldown = failureCooldown
        self.directMultipath = directMultipath
    }

    func setRoutes(directInterfaceTypes: [NWInterface.InterfaceType],
                   moblinkRelays: [WebNetworkMoblinkRelay])
    {
        let newRoutes = makeRoutes(directInterfaceTypes: directInterfaceTypes, moblinkRelays: moblinkRelays)
        routes = newRoutes.map { route in
            routes.first(where: { $0.route == route }) ?? .init(route: route)
        }
    }

    func nextRoute(now: Date = Date()) -> WebNetworkRoute? {
        routes
            .filter { isAvailable(route: $0, now: now) }
            .sorted(by: { routeScore($0, now: now) < routeScore($1, now: now) })
            .first?
            .route
    }

    func connectionStarted(route: WebNetworkRoute) {
        guard let index = routes.firstIndex(where: { $0.route == route }) else {
            return
        }
        routes[index].activeConnectionCount += 1
    }

    func connectionFinished(route: WebNetworkRoute, success: Bool, now: Date = Date()) {
        guard let index = routes.firstIndex(where: { $0.route == route }) else {
            return
        }
        routes[index].activeConnectionCount = max(0, routes[index].activeConnectionCount - 1)
        if success {
            routes[index].failureCount = 0
            routes[index].lastFailureTime = nil
        } else {
            routes[index].failureCount += 1
            routes[index].lastFailureTime = now
        }
    }

    private func isAvailable(route: WebNetworkRouteState, now: Date) -> Bool {
        guard let lastFailureTime = route.lastFailureTime else {
            return true
        }
        return now.timeIntervalSince(lastFailureTime) >= failureCooldown
    }

    private func routeScore(_ route: WebNetworkRouteState, now: Date) -> Int {
        var score = routePriority(route.route)
        score += route.activeConnectionCount * 50
        score += route.failureCount * 100
        if !isAvailable(route: route, now: now) {
            score += 1000
        }
        return score
    }

    private func makeRoutes(directInterfaceTypes: [NWInterface.InterfaceType],
                            moblinkRelays: [WebNetworkMoblinkRelay]) -> [WebNetworkRoute]
    {
        var routes: [WebNetworkRoute] = []
        if directMultipath, supportsDirectMultipath(directInterfaceTypes: directInterfaceTypes) {
            routes.append(.directMultipath)
        }
        for interfaceType in preferredDirectInterfaceTypes {
            if directInterfaceTypes.contains(interfaceType) {
                routes.append(.direct(interfaceType))
            }
        }
        for relay in moblinkRelays {
            routes.append(.moblink(relay.id))
        }
        return routes
    }

    private func routePriority(_ route: WebNetworkRoute) -> Int {
        switch route {
        case .directMultipath:
            0
        case let .direct(interfaceType):
            switch interfaceType {
            case .cellular:
                10
            case .wiredEthernet:
                30
            case .wifi:
                40
            case .other:
                50
            default:
                60
            }
        case .moblink:
            20
        }
    }

    private func supportsDirectMultipath(directInterfaceTypes: [NWInterface.InterfaceType]) -> Bool {
        guard directInterfaceTypes.contains(.cellular) else {
            return false
        }
        return directInterfaceTypes.contains(.wifi)
    }
}

private let preferredDirectInterfaceTypes: [NWInterface.InterfaceType] = [
    .cellular,
    .wiredEthernet,
    .wifi,
    .other,
]
