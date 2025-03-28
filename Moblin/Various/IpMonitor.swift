import Foundation
import Network

class IPMonitor {
    enum IPType: String {
        case ipv4 = "IPv4"
        case ipv6 = "ipV6"

        func formatAddress(_ address: String) -> String {
            switch self {
            case .ipv4:
                return address
            case .ipv6:
                return "[\(address)]"
            }
        }
    }

    struct Status: Identifiable {
        var id: Int
        var name: String
        var interfaceType: NWInterface.InterfaceType
        var ip: String
        var ipType: IPMonitor.IPType
    }

    private let monitor = NWPathMonitor()
    final var pathUpdateHandler: (([Status]) -> Void)?

    init() {
        monitor.pathUpdateHandler = { path in
            var statuses: [Status] = []
            var id = 0
            for interface in path.availableInterfaces {
                for (ip, type) in self.getIpAddresses(interfaceName: interface.name) {
                    statuses.append(Status(
                        id: id,
                        name: interface.name,
                        interfaceType: interface.type,
                        ip: ip,
                        ipType: type
                    ))
                    id += 1
                }
            }
            self.pathUpdateHandler?(statuses)
        }
    }

    func start() {
        monitor.start(queue: .main)
    }

    private func getIpAddresses(interfaceName: String) -> [(String, IPMonitor.IPType)] {
        var addresses: [(String, IPMonitor.IPType)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == interfaceName {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(
                            interface?.ifa_addr,
                            socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            socklen_t(0),
                            NI_NUMERICHOST
                        )
                        let hostnameString = String(cString: hostname)
                        let type: IPMonitor.IPType = addrFamily == UInt8(AF_INET) ? .ipv4 : .ipv6
                        let address = (hostnameString, type)
                        if !addresses.contains(where: { $0 == address }) {
                            addresses.append(address)
                        }
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return addresses
    }
}
