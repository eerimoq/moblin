import Foundation
import Network

class IPMonitor {
    enum IPType: String {
        case ipv4 = "IPv4"
        case ipv6 = "ipV6"
    }

    struct Status {
        var name: String
        var interfaceType: NWInterface.InterfaceType
        var ip: String
    }

    private let monitor = NWPathMonitor()
    final var pathUpdateHandler: (([Status]) -> Void)?

    init(ipType: IPType) {
        monitor.pathUpdateHandler = { path in
            var statuses: [Status] = []
            for interface in path.availableInterfaces {
                for ip in self.getIPAddresses(interfaceName: interface.name, ipType: ipType) {
                    statuses.append(Status(
                        name: interface.name,
                        interfaceType: interface.type,
                        ip: ip
                    ))
                }
            }
            self.pathUpdateHandler?(statuses)
        }
    }

    func start() {
        monitor.start(queue: DispatchQueue.main)
    }

    private func getIPAddresses(interfaceName: String, ipType: IPType) -> [String] {
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if (addrFamily == UInt8(AF_INET) && ipType == .ipv4)
                    || (addrFamily == UInt8(AF_INET6) && ipType == .ipv6)
                {
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
                        addresses.append(String(cString: hostname))
                    }
                }
            }
        }
        freeifaddrs(ifaddr)

        return addresses
    }
}
