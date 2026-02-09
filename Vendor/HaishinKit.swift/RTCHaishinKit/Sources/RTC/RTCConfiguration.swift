import Foundation
import libdatachannel

public protocol RTCConfigurationConvertible: Sendable {
    /// A list of ICE server URLs used to establish the connection.
    var iceServers: [String] { get }
    /// The local IP address to bind sockets to.
    var bindAddress: String? { get }
    /// The type of certificate to generate for DTLS handshakes.
    var certificateType: RTCCertificateType? { get }
    /// The ICE transport policy that controls how candidates are gathered.
    var iceTransportPolicy: RTCTransportPolicy? { get }
    /// A Boolean value that indicates whether ICE UDP multiplexing is enabled.
    var isIceUdpMuxEnabled: Bool { get }
    /// A Boolean value that indicates whether negotiation is performed automatically.
    var isAutoNegotionEnabled: Bool { get }
    /// A Boolean value that forces the use of media transport even for data sessions.
    var isForceMediaTransport: Bool { get }
    /// The port range available for allocating ICE candidates.
    var portRange: Range<UInt16>? { get }
    /// The maximum transmission unit (MTU) for outgoing packets.
    var mtu: Int32? { get }
    /// The maximum message size allowed for data channels.
    var maxMesasgeSize: Int32? { get }
}

extension RTCConfigurationConvertible {
    func createPeerConnection() -> Int32 {
        return iceServers.withCStringArray { cIceServers in
            return [bindAddress ?? ""].withCStrings { cStrings in
                var config = rtcConfiguration()
                if !iceServers.isEmpty {
                    config.iceServers = cIceServers
                    config.iceServersCount = Int32(iceServers.count)
                }
                if bindAddress != nil {
                    config.bindAddress = cStrings[0]
                }
                if let certificateType {
                    config.certificateType = certificateType.cValue
                }
                if let iceTransportPolicy {
                    config.iceTransportPolicy = iceTransportPolicy.cValue
                }
                config.enableIceUdpMux = isIceUdpMuxEnabled
                config.disableAutoNegotiation = !isAutoNegotionEnabled
                config.forceMediaTransport = isForceMediaTransport
                if let portRange {
                    config.portRangeBegin = portRange.lowerBound
                    config.portRangeEnd = portRange.upperBound
                }
                if let mtu {
                    config.mtu = mtu
                }
                if let maxMesasgeSize {
                    config.maxMessageSize = maxMesasgeSize
                }
                return rtcCreatePeerConnection(&config)
            }
        }
    }
}

public struct RTCConfiguration: RTCConfigurationConvertible {
    static let empty = RTCConfiguration()

    public let iceServers: [String]
    public let bindAddress: String?
    public let certificateType: RTCCertificateType?
    public let iceTransportPolicy: RTCTransportPolicy?
    public let isIceUdpMuxEnabled: Bool
    public let isAutoNegotionEnabled: Bool
    public let isForceMediaTransport: Bool
    public let portRange: Range<UInt16>?
    public let mtu: Int32?
    public let maxMesasgeSize: Int32?

    public init(
        iceServers: [String] = [],
        bindAddress: String? = nil,
        certificateType: RTCCertificateType? = nil,
        iceTransportPolicy: RTCTransportPolicy? = nil,
        isIceUdpMuxEnabled: Bool = false,
        isAutoNegotionEnabled: Bool = true,
        isForceMediaTransport: Bool = false,
        portRange: Range<UInt16>? = nil,
        mtu: Int32? = nil,
        maxMesasgeSize: Int32? = nil
    ) {
        self.iceServers = iceServers
        self.bindAddress = bindAddress
        self.certificateType = certificateType
        self.iceTransportPolicy = iceTransportPolicy
        self.isIceUdpMuxEnabled = isIceUdpMuxEnabled
        self.isAutoNegotionEnabled = isAutoNegotionEnabled
        self.isForceMediaTransport = isForceMediaTransport
        self.portRange = portRange
        self.mtu = mtu
        self.maxMesasgeSize = maxMesasgeSize
    }
}
