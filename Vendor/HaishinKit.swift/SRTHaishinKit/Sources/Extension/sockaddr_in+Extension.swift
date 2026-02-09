import Foundation

extension sockaddr_in {
    var size: Int {
        return MemoryLayout.size(ofValue: self)
    }

    init?(_ host: String, port: Int) {
        self.init()
        self.sin_family = sa_family_t(AF_INET)
        self.sin_port = CFSwapInt16BigToHost(UInt16(port))
        if inet_pton(AF_INET, host, &sin_addr) == 1 {
            return
        }
        guard let hostent = gethostbyname(host), hostent.pointee.h_addrtype == AF_INET else {
            return nil
        }
        if let h_addr_list = hostent.pointee.h_addr_list[0] {
            self.sin_addr = UnsafeRawPointer(h_addr_list).assumingMemoryBound(to: in_addr.self).pointee
        } else {
            return nil
        }
    }

    mutating func makeSockaddr() -> sockaddr {
        var address = sockaddr()
        memcpy(&address, &self, size)
        return address
    }
}
