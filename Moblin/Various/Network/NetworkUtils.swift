import Network

extension NWPath {
    // The list contains duplicates since iOS 26. Apple bug?
    func uniqueAvailableInterfaces() -> [NWInterface] {
        var interfaces: [NWInterface] = []
        for interface in availableInterfaces where !interfaces.contains(interface) {
            interfaces.append(interface)
        }
        return interfaces
    }
}

extension NWEndpoint.Port {
    init(integer: Int) {
        self.init(integerLiteral: UInt16(clamping: integer))
    }
}
