import AVFoundation

// | 4b header size | <m>b header | <n>b buffer |

struct SampleBufferHeaderTime: Codable {
    var value: CMTimeValue
    var timescale: CMTimeScale

    // periphery:ignore
    init(cmTime: CMTime) {
        value = cmTime.value
        timescale = cmTime.timescale
    }

    func toCMTime() -> CMTime {
        return .init(value: value, timescale: timescale)
    }
}

struct SampleBufferHeader: Codable {
    var bufferType: Int
    var bufferSize: Int
    var mediaSubType: FourCharCode
    var width: Int32
    var height: Int32
    var presentationTimeStamp: SampleBufferHeaderTime
    // periphery:ignore
    var debug: String
}

func createContainerDir(appGroup: String) throws -> URL {
    guard let containerDir = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    else {
        throw "Failed to create container directory"
    }
    try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
    return containerDir
}

func createSocketPath(containerDir: URL) -> URL {
    return containerDir.appendingPathComponent("sb.sock")
}

func removeFile(path: URL) {
    do {
        try FileManager.default.removeItem(at: path)
    } catch {}
}

func createAddr(path: URL) throws -> sockaddr_un {
    let path = path.path
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathLength = path.withCString { Int(strlen($0)) }
    guard MemoryLayout.size(ofValue: addr.sun_path) > pathLength else {
        throw "sample-buffer: unix socket path \(path) too long"
    }
    _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { addrPtr in
        path.withCString {
            strncpy(addrPtr, $0, pathLength)
        }
    }
    return addr
}

func createSocket() throws -> Int32 {
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    if fd == -1 {
        throw "Failed to create unix socket"
    }
    return fd
}

func setIgnoreSigPipe(fd: Int32) throws {
    var on: Int32 = 1
    if setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size)) == -1 {
        throw "Failed to set ignore sigpipe"
    }
}
