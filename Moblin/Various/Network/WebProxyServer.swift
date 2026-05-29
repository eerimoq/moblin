import Foundation
import Network
import Security
import WebKit

private let webProxyQueue = DispatchQueue(label: "com.eerimoq.web-proxy")
private let webProxyOpenTimeout = 10.0

final class WebProxyServer: @unchecked Sendable {
    private var listener: NWListener?
    private let routeSelector: WebNetworkRouteSelector
    private var networkPathMonitor: NWPathMonitor?
    private var directInterfaceTypes: [NWInterface.InterfaceType] = []
    private var moblinkRelays: [WebNetworkMoblinkRelay] = []
    private weak var moblinkRelayConnector: (any WebNetworkMoblinkRelayConnector)?
    private let enabled: Atomic<Bool> = .init(false)
    private let port: Atomic<UInt16?> = .init(nil)

    init() {
        routeSelector = .init(directMultipath: webProxyServerHasMultipathEntitlement())
    }

    func setEnabled(_ enabled: Bool) {
        webProxyQueue.async {
            guard enabled != self.enabled.value else {
                return
            }
            self.enabled.mutate { $0 = enabled }
            if enabled {
                self.startInternal()
            } else {
                self.stopInternal()
            }
        }
    }

    func setMoblinkRelays(_ moblinkRelays: [WebNetworkMoblinkRelay]) {
        webProxyQueue.async {
            self.moblinkRelays = moblinkRelays
            self.updateRoutes()
        }
    }

    func setMoblinkRelayConnector(_ moblinkRelayConnector: (any WebNetworkMoblinkRelayConnector)?) {
        webProxyQueue.async {
            self.moblinkRelayConnector = moblinkRelayConnector
            if moblinkRelayConnector == nil {
                self.moblinkRelays.removeAll()
                self.updateRoutes()
            }
        }
    }

    @MainActor
    func configureWebView(configuration: WKWebViewConfiguration) {
        guard enabled.value, let port = port.value else {
            return
        }
        if #available(iOS 17.0, *) {
            let endpoint = NWEndpoint.hostPort(host: .ipv4(.loopback),
                                               port: NWEndpoint.Port(integerLiteral: port))
            var proxyConfiguration = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: nil)
            proxyConfiguration.allowFailover = true
            let websiteDataStore = configuration.websiteDataStore
            websiteDataStore.proxyConfigurations = [proxyConfiguration]
            configuration.websiteDataStore = websiteDataStore
        }
    }

    private func startInternal() {
        guard enabled.value, listener == nil else {
            return
        }
        do {
            let parameters = NWParameters.tcp
            parameters.acceptLocalOnly = true
            listener = try NWListener(using: parameters)
        } catch {
            logger.info("web-proxy: Failed to create listener with error \(error)")
            return
        }
        listener?.stateUpdateHandler = handleStateChange(to:)
        listener?.newConnectionHandler = handleNewConnection(connection:)
        listener?.start(queue: webProxyQueue)
        let networkPathMonitor = NWPathMonitor()
        networkPathMonitor.pathUpdateHandler = handleNetworkPathUpdate(path:)
        networkPathMonitor.start(queue: webProxyQueue)
        self.networkPathMonitor = networkPathMonitor
    }

    private func stopInternal() {
        listener?.cancel()
        listener = nil
        networkPathMonitor?.cancel()
        networkPathMonitor = nil
        directInterfaceTypes.removeAll()
        port.mutate { $0 = nil }
        updateRoutes()
    }

    private func handleStateChange(to state: NWListener.State) {
        switch state {
        case .ready:
            let port = listener?.port?.rawValue
            self.port.mutate { $0 = port }
            logger.info("web-proxy: Listening on port \(port ?? 0)")
        case let .failed(error):
            logger.info("web-proxy: Listener failed with error \(error)")
            listener?.cancel()
            listener = nil
        default:
            break
        }
    }

    private func handleNewConnection(connection: NWConnection) {
        let proxyConnection = WebProxyConnection(connection: connection,
                                                 routeSelector: routeSelector,
                                                 moblinkRelayConnector: moblinkRelayConnector)
        proxyConnection.start()
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        directInterfaceTypes = path.uniqueAvailableInterfaces().map(\.type)
        updateRoutes()
    }

    private func updateRoutes() {
        routeSelector.setRoutes(directInterfaceTypes: directInterfaceTypes,
                                moblinkRelays: moblinkRelays)
    }
}

private final class WebProxyConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let routeSelector: WebNetworkRouteSelector
    private weak var moblinkRelayConnector: (any WebNetworkMoblinkRelayConnector)?
    private let parser = WebProxyRequestParser()
    private var destinationConnection: NWConnection?
    private var moblinkConnection: (any WebNetworkMoblinkConnection)?
    private var selectedRoute: WebNetworkRoute?
    private var routeOpened = false
    private let openTimer = SimpleTimer(queue: webProxyQueue)
    private var stopped = false

    init(connection: NWConnection,
         routeSelector: WebNetworkRouteSelector,
         moblinkRelayConnector: (any WebNetworkMoblinkRelayConnector)?)
    {
        self.connection = connection
        self.routeSelector = routeSelector
        self.moblinkRelayConnector = moblinkRelayConnector
    }

    func start() {
        connection.start(queue: webProxyQueue)
        receiveRequest()
    }

    private func receiveRequest() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, _, error in
            guard error == nil, let data, !data.isEmpty else {
                self.stop(success: false)
                return
            }
            self.parser.append(data: data)
            let (done, request) = self.parser.parse()
            guard done else {
                self.receiveRequest()
                return
            }
            guard let request else {
                self.stop(success: false)
                return
            }
            self.openNextRoute(request: request)
        }
    }

    private func openNextRoute(request: WebProxyRequest) {
        guard !stopped else {
            return
        }
        guard let route = routeSelector.nextRoute() else {
            stop(success: false)
            return
        }
        selectedRoute = route
        routeOpened = false
        routeSelector.connectionStarted(route: route)
        startOpenTimer(route: route, request: request)
        switch request {
        case let .connect(host, port, _):
            open(host: host,
                 port: port,
                 initialData: nil,
                 sendConnectResponse: true,
                 route: route,
                 request: request)
        case let .http(host, port, httpRequest):
            open(host: host,
                 port: port,
                 initialData: httpRequest,
                 sendConnectResponse: false,
                 route: route,
                 request: request)
        }
    }

    private func open(host: String,
                      port: UInt16,
                      initialData: Data?,
                      sendConnectResponse: Bool,
                      route: WebNetworkRoute,
                      request: WebProxyRequest)
    {
        switch route {
        case .directMultipath, .direct:
            openDirect(host: host,
                       port: port,
                       initialData: initialData,
                       sendConnectResponse: sendConnectResponse,
                       route: route,
                       request: request)
        case let .moblink(relayId):
            openMoblink(relayId: relayId,
                        host: host,
                        port: port,
                        initialData: initialData,
                        sendConnectResponse: sendConnectResponse,
                        request: request)
        }
    }

    private func openDirect(host: String,
                            port: UInt16,
                            initialData: Data?,
                            sendConnectResponse: Bool,
                            route: WebNetworkRoute,
                            request: WebProxyRequest)
    {
        let parameters = NWParameters.tcp
        switch route {
        case .directMultipath:
            parameters.multipathServiceType = .aggregate
        case let .direct(interfaceType):
            parameters.requiredInterfaceType = interfaceType
        case .moblink:
            openNextRouteAfterFailure(request: request)
            return
        }
        parameters.prohibitExpensivePaths = false
        parameters.prohibitConstrainedPaths = false
        destinationConnection = NWConnection(host: NWEndpoint.Host(host),
                                             port: NWEndpoint.Port(integerLiteral: port),
                                             using: parameters)
        destinationConnection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.openTimer.stop()
                self.routeOpened = true
                if sendConnectResponse {
                    self.connection.send(content: "HTTP/1.1 200 OK\r\n\r\n".utf8Data,
                                         completion: .idempotent)
                }
                if let initialData {
                    self.destinationConnection?.send(content: initialData, completion: .idempotent)
                }
                self.relayClientToDestination()
                self.relayDestinationToClient()
            case .failed:
                if self.routeOpened {
                    self.stop(success: false)
                } else {
                    self.openNextRouteAfterFailure(request: request)
                }
            default:
                break
            }
        }
        destinationConnection?.start(queue: webProxyQueue)
    }

    private func openMoblink(relayId: UUID,
                             host: String,
                             port: UInt16,
                             initialData: Data?,
                             sendConnectResponse: Bool,
                             request: WebProxyRequest)
    {
        let route = WebNetworkRoute.moblink(relayId)
        guard let moblinkRelayConnector else {
            openNextRouteAfterFailure(request: request)
            return
        }
        moblinkRelayConnector.openWebProxyConnection(
            relayId: relayId,
            host: host,
            port: port,
            delegate: self
        ) { connection in
            webProxyQueue.async {
                guard !self.stopped,
                      self.selectedRoute == route,
                      !self.routeOpened
                else {
                    connection?.close()
                    return
                }
                guard let connection else {
                    self.openNextRouteAfterFailure(request: request)
                    return
                }
                self.openTimer.stop()
                self.routeOpened = true
                self.moblinkConnection = connection
                if sendConnectResponse {
                    self.connection.send(content: "HTTP/1.1 200 OK\r\n\r\n".utf8Data,
                                         completion: .idempotent)
                }
                if let initialData {
                    connection.send(data: initialData)
                }
                self.relayClientToMoblink()
            }
        }
    }

    private func startOpenTimer(route: WebNetworkRoute, request: WebProxyRequest) {
        openTimer.startSingleShot(timeout: webProxyOpenTimeout) { [weak self] in
            guard let self,
                  selectedRoute == route,
                  !self.routeOpened
            else {
                return
            }
            openNextRouteAfterFailure(request: request)
        }
    }

    private func openNextRouteAfterFailure(request: WebProxyRequest) {
        guard let selectedRoute else {
            stop(success: false)
            return
        }
        openTimer.stop()
        routeSelector.connectionFinished(route: selectedRoute, success: false)
        self.selectedRoute = nil
        destinationConnection?.stateUpdateHandler = nil
        destinationConnection?.cancel()
        destinationConnection = nil
        moblinkConnection?.close()
        moblinkConnection = nil
        openNextRoute(request: request)
    }

    private func relayClientToDestination() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, _, error in
            guard error == nil, let data, !data.isEmpty else {
                self.stop(success: true)
                return
            }
            self.destinationConnection?.send(content: data, completion: .idempotent)
            self.relayClientToDestination()
        }
    }

    private func relayClientToMoblink() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, _, error in
            guard error == nil, let data, !data.isEmpty else {
                self.stop(success: true)
                return
            }
            self.moblinkConnection?.send(data: data)
            self.relayClientToMoblink()
        }
    }

    private func relayDestinationToClient() {
        destinationConnection?.receive(
            minimumIncompleteLength: 1,
            maximumLength: 16 * 1024
        ) { data, _, _, error in
            guard error == nil, let data, !data.isEmpty else {
                self.stop(success: true)
                return
            }
            self.connection.send(content: data, completion: .idempotent)
            self.relayDestinationToClient()
        }
    }

    private func stop(success: Bool) {
        guard !stopped else {
            return
        }
        stopped = true
        openTimer.stop()
        if let selectedRoute {
            routeSelector.connectionFinished(route: selectedRoute, success: success)
        }
        destinationConnection?.cancel()
        destinationConnection = nil
        moblinkConnection?.close()
        moblinkConnection = nil
        connection.cancel()
    }
}

private func webProxyServerHasMultipathEntitlement() -> Bool {
    guard let task = SecTaskCreateFromSelf(nil),
          let value = SecTaskCopyValueForEntitlement(
              task,
              "com.apple.developer.networking.multipath" as CFString,
              nil
          ) as? Bool
    else {
        return false
    }
    return value
}

extension WebProxyConnection: WebNetworkMoblinkConnectionDelegate {
    func webNetworkMoblinkConnectionReceiveData(data: Data) {
        webProxyQueue.async {
            guard !self.stopped else {
                return
            }
            self.connection.send(content: data, completion: .idempotent)
        }
    }

    func webNetworkMoblinkConnectionClosed() {
        webProxyQueue.async {
            self.stop(success: true)
        }
    }
}
