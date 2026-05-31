import Network

private let proxyPort: UInt16 = 2000

extension Model {
    func proxyServerChanged() {
        reloadProxyServer()
        setWebBrowserProxy()
        resetSelectedScene()
    }

    func reloadProxyServer() {
        stopProxyServer()
        if database.debug.httpProxy {
            startProxyServer()
        }
    }

    func getProxyServerEndpoint() -> NWEndpoint? {
        if database.debug.httpProxy {
            .hostPort(host: .init("127.0.0.1"), port: .init(integerLiteral: proxyPort))
        } else {
            nil
        }
    }

    private func stopProxyServer() {
        proxyServer?.stop()
        proxyServer = nil
    }

    private func startProxyServer() {
        proxyServer = HttpProxyServer()
        proxyServer?.start(port: .init(integerLiteral: proxyPort))
    }
}
