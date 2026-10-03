import Network

extension Model {
    func httpProxyServerChanged() {
        reloadHttpProxyServer()
    }

    func reloadHttpProxyServer() {
        stopHttpProxyServer()
        let httpProxy = database.httpProxy
        if httpProxy.enabled || httpProxy.localNetwork {
            startHttpProxyServer()
        } else {
            proxyServerPortUpdated()
        }
    }

    func getHttpProxyServerEndpoint() -> NWEndpoint? {
        if database.httpProxy.enabled, let httpProxyPort {
            .hostPort(host: .init("127.0.0.1"), port: httpProxyPort)
        } else {
            nil
        }
    }

    private func proxyServerPortUpdated() {
        let endpoint = getHttpProxyServerEndpoint()
        setWebBrowserProxy()
        setBrowserEffectsProxyServer()
        EmotesPlayer.shared.setProxyServer(endpoint: endpoint)
        setHttpUrlSessionProxyServer(endpoint: endpoint)
    }

    private func startHttpProxyServer() {
        let httpProxy = database.httpProxy
        httpProxyServer = HttpProxyServer()
        httpProxyServer?.delegate = self
        httpProxyServer?.start(port: httpProxy.port, localNetwork: httpProxy.localNetwork)
    }

    func stopHttpProxyServer() {
        httpProxyServer?.stop()
        httpProxyServer = nil
        httpProxyPort = nil
    }
}

extension Model: HttpProxyServerDelegate {
    nonisolated func httpProxyServerPortReady(port: NWEndpoint.Port) {
        DispatchQueue.main.async {
            self.httpProxyPort = port
            self.proxyServerPortUpdated()
        }
    }
}
