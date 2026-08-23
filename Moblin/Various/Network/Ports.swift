import Foundation

enum DefaultTcpPorts {
    static let remoteControlWeb: UInt16 = 80
    static let rtmpServer: UInt16 = 1935
    static let remoteControlAssistant: UInt16 = 2345
    static let moblinkStreamer: UInt16 = 7777
    static let mobcamStream: UInt16 = 7790
    static let whipServer: UInt16 = 8310
}

enum DefaultUdpPorts {
    static let srtServer: UInt16 = 4000
    static let srtlaServer: UInt16 = 5000
    static let ristServer: UInt16 = 6500
}
