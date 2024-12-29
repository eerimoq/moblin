import Network

func performDnsLookup(host: String) -> String? {
    var hints = addrinfo(
        ai_flags: 0,
        ai_family: AF_UNSPEC,
        ai_socktype: SOCK_DGRAM,
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )
    var infoPointer: UnsafeMutablePointer<addrinfo>?
    let status = getaddrinfo(host, nil, &hints, &infoPointer)
    if status != 0 {
        if let errorString = gai_strerror(status) {
            logger.error("dns: Lookup of \(host) failed with \(String(cString: errorString))")
        }
        return nil
    }
    var addresses: [String] = []
    var pointer = infoPointer
    while pointer != nil {
        if let address = pointer?.pointee.ai_addr {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                address,
                socklen_t(pointer!.pointee.ai_addrlen),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                addresses.append(String(cString: hostname))
            }
        }
        pointer = pointer?.pointee.ai_next
    }
    freeaddrinfo(infoPointer)
    for address in addresses {
        logger.info("dns: Found address \(address) for \(host)")
        return address
    }
    return nil
}
