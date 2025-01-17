import Foundation
import Network

struct MoblinkScannerServer: Identifiable {
    var id = UUID()
    var name: String
    var urls: [String]
}

private class DiscoveredSerivce {
    var service: NetService
    var urls: [String]

    init(service: NetService) {
        self.service = service
        urls = []
    }
}

protocol MoblinkScannerDelegate: AnyObject {
    func moblinkScannerDiscoveredServers(servers: [MoblinkScannerServer])
}

class MoblinkScanner: NSObject {
    private var browser: NetServiceBrowser?
    private var services: [DiscoveredSerivce] = []
    private weak var delegate: (any MoblinkScannerDelegate)?

    init(delegate: MoblinkScannerDelegate) {
        self.delegate = delegate
    }

    func start() {
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: moblinkBonjourType, inDomain: moblinkBonjourDomain)
    }

    func stop() {
        browser?.stop()
        browser = nil
        services.removeAll()
    }

    private func discoveredServersUpdated() {
        var servers: [MoblinkScannerServer] = []
        for service in services {
            guard let data = service.service.txtRecordData() else {
                continue
            }
            let metadata = NetService.dictionary(fromTXTRecord: data)
            guard let nameData = metadata["name"] else {
                return
            }
            guard let name = String(bytes: nameData, encoding: .utf8) else {
                return
            }
            servers.append(.init(name: name, urls: service.urls))
        }
        delegate?.moblinkScannerDiscoveredServers(servers: servers)
    }
}

extension MoblinkScanner: NetServiceBrowserDelegate {
    func netServiceBrowser(_: NetServiceBrowser, didFind service: NetService, moreComing _: Bool) {
        guard !services.contains(where: { $0.service == service }) else {
            return
        }
        services.append(.init(service: service))
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_: NetServiceBrowser, didRemove service: NetService, moreComing _: Bool) {
        guard let index = services.firstIndex(where: { $0.service == service }) else {
            return
        }
        services.remove(at: index)
        discoveredServersUpdated()
    }
}

extension MoblinkScanner: NetServiceDelegate {
    func netServiceDidResolveAddress(_ service: NetService) {
        guard let discoveredService = services.first(where: { $0.service == service }) else {
            return
        }
        for address in service.addresses ?? [] {
            let (address, ipv6) = getAddressInfo(address: address)
            if let url = formatWebsocketUrl(address: address, ipv6: ipv6, port: service.port) {
                discoveredService.urls.append(url)
            }
        }
        discoveredServersUpdated()
    }

    private func getAddressInfo(address: Data) -> (String, Bool) {
        var ipv6 = false
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        address.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
            let sockaddrPtr = pointer.bindMemory(to: sockaddr.self)
            guard let unsafePtr = sockaddrPtr.baseAddress else {
                return
            }
            guard getnameinfo(
                unsafePtr,
                socklen_t(address.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 else {
                return
            }
            ipv6 = unsafePtr.pointee.sa_family == AF_INET6
        }
        return (String(cString: hostname), ipv6)
    }

    private func formatWebsocketUrl(address: String, ipv6: Bool, port: Int) -> String? {
        var host: String
        if ipv6 {
            guard let address6 = IPv6Address(address), !address6.isLinkLocal, !address6.isLoopback else {
                return nil
            }
            host = "[\(address)]"
        } else {
            guard let address4 = IPv4Address(address), !address4.isLinkLocal, !address4.isLoopback else {
                return nil
            }
            host = address
        }
        return "ws://\(host):\(port)"
    }
}
