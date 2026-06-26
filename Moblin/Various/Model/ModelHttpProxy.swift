import Network

extension Model {
    func httpProxyServerChanged() {
        reloadHttpProxyServer()
    }

    func reloadHttpProxyServer() {
        stopHttpProxyServer()
        if database.debug.httpProxy {
            startHttpProxyServer()
        } else {
            proxyServerPortUpdated()
        }
    }

    func getHttpProxyServerEndpoint() -> NWEndpoint? {
        if database.debug.httpProxy, let httpProxyPort {
            .hostPort(host: .init("127.0.0.1"), port: httpProxyPort)
        } else {
            nil
        }
    }

    private func proxyServerPortUpdated() {
        setWebBrowserProxy()
        setBrowserEffectsProxyServer()
    }

    private func startHttpProxyServer() {
        httpProxyServer = HttpProxyServer()
        httpProxyServer?.delegate = self
        httpProxyServer?.start()
    }

    func stopHttpProxyServer() {
        httpProxyServer?.stop()
        httpProxyServer = nil
        httpProxyPort = nil
    }
}

extension Model: @preconcurrency HttpProxyServerDelegate {
    func httpProxyServerPortReady(port: NWEndpoint.Port) {
        DispatchQueue.main.async {
            self.httpProxyPort = port
            self.proxyServerPortUpdated()
        }
    }
}
