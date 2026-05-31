import Network

private let proxyPort: UInt16 = 2000

extension Model {
    func httpProxyServerChanged() {
        reloadHttpProxyServer()
        setWebBrowserProxy()
        resetSelectedScene()
    }

    func reloadHttpProxyServer() {
        stopHttpProxyServer()
        if database.debug.httpProxy {
            startHttpProxyServer()
        }
    }

    func getHttpProxyServerEndpoint() -> NWEndpoint? {
        if database.debug.httpProxy {
            .hostPort(host: .init("127.0.0.1"), port: .init(integerLiteral: proxyPort))
        } else {
            nil
        }
    }

    private func startHttpProxyServer() {
        httpProxyServer = HttpProxyServer()
        httpProxyServer?.start(port: .init(integerLiteral: proxyPort))
    }

    private func stopHttpProxyServer() {
        httpProxyServer?.stop()
        httpProxyServer = nil
    }
}
