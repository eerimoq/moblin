import Foundation
import Network

private let webRtcIceQueue = DispatchQueue(label: "com.eerimoq.Moblin.webrtc.ice")

struct IceCandidate {
    let foundation: String
    let component: Int
    let transport: String
    let priority: UInt32
    let address: String
    let port: Int
    let type: String

    func toSdpCandidate() -> SdpCandidate {
        return SdpCandidate(
            foundation: foundation,
            component: component,
            transport: transport,
            priority: priority,
            address: address,
            port: port,
            type: type
        )
    }
}

protocol IceAgentDelegate: AnyObject {
    func iceAgentDidGatherLocalCandidates(_ candidates: [IceCandidate])
}

class IceAgent {
    private var localCandidates: [IceCandidate] = []
    weak var delegate: IceAgentDelegate?
    let ufrag: String
    let pwd: String

    init() {
        ufrag = IceAgent.generateIceString(length: 4)
        pwd = IceAgent.generateIceString(length: 22)
    }

    func gatherLocalCandidates() {
        webRtcIceQueue.async {
            self.gatherLocalCandidatesInternal()
        }
    }

    private func gatherLocalCandidatesInternal() {
        var candidates: [IceCandidate] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            delegate?.iceAgentDidGatherLocalCandidates([])
            return
        }
        defer { freeifaddrs(ifaddr) }
        var currentAddr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = currentAddr {
            let flags = Int32(addr.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else {
                currentAddr = addr.pointee.ifa_next
                continue
            }
            guard let sockAddr = addr.pointee.ifa_addr else {
                currentAddr = addr.pointee.ifa_next
                continue
            }
            let family = sockAddr.pointee.sa_family
            if family == sa_family_t(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    sockAddr,
                    socklen_t(MemoryLayout<sockaddr_in>.size),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    let address = String(cString: hostname)
                    let candidate = IceCandidate(
                        foundation: "1",
                        component: 1,
                        transport: "UDP",
                        priority: computePriority(type: "host", component: 1),
                        address: address,
                        port: 0,
                        type: "host"
                    )
                    candidates.append(candidate)
                }
            }
            currentAddr = addr.pointee.ifa_next
        }
        localCandidates = candidates
        delegate?.iceAgentDidGatherLocalCandidates(candidates)
    }

    static func generateIceString(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/"
        return String((0 ..< length).map { _ in chars.randomElement()! })
    }
}

private func computePriority(type: String, component: Int) -> UInt32 {
    let typePreference: UInt32
    switch type {
    case "host":
        typePreference = 126
    case "srflx":
        typePreference = 100
    case "relay":
        typePreference = 0
    default:
        typePreference = 0
    }
    let localPreference: UInt32 = 65535
    return (typePreference << 24) | (localPreference << 8) | UInt32(256 - component)
}
