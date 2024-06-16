import Foundation
import libsrt

protocol SRTSocketDelegate: AnyObject {
    func socket(_ socket: SRTSocket, status: SRT_SOCKSTATUS)
    func socket(_ socket: SRTSocket, sendHook data: Data) -> Bool
}

final class SRTSocket {
    var options: [SRTSocketOption: String] = [:]
    weak var delegate: (any SRTSocketDelegate)?
    private(set) var perf = CBytePerfMon()
    private(set) var isRunning: Atomic<Bool> = .init(false)
    private(set) var socket: SRTSOCKET = SRT_INVALID_SOCK
    private(set) var status: SRT_SOCKSTATUS = SRTS_INIT {
        didSet {
            guard status != oldValue else {
                return
            }
            switch status {
            case SRTS_INIT: // 1
                logger.debug("SRT Socket Init")
            case SRTS_OPENED:
                logger.info("SRT Socket opened")
            case SRTS_LISTENING:
                logger.debug("SRT Socket Listening")
            case SRTS_CONNECTING:
                logger.debug("SRT Socket Connecting")
            case SRTS_CONNECTED:
                logger.info("SRT Socket Connected")
            case SRTS_BROKEN:
                logger.info("SRT Socket Broken")
                close()
            case SRTS_CLOSING:
                logger.debug("SRT Socket Closing")
            case SRTS_CLOSED:
                logger.info("SRT Socket Closed")
                stopRunning()
            case SRTS_NONEXIST:
                logger.info("SRT Socket Not Exist")
                stopRunning()
            default:
                break
            }
            delegate?.socket(self, status: status)
        }
    }

    init() {}

    func open(_ addr: sockaddr_in, _ options: [SRTSocketOption: String]) throws {
        guard socket == SRT_INVALID_SOCK else {
            return
        }
        socket = srt_create_socket()
        if socket == SRT_INVALID_SOCK {
            throw makeSocketError()
        }
        let context = Unmanaged.passRetained(self).toOpaque()
        srt_send_callback(socket,
                          { context, _, buf1, size1, buf2, size2 in
                              guard let context, let buf1, let buf2 else {
                                  return -1
                              }
                              let socket: SRTSocket = Unmanaged.fromOpaque(context).takeUnretainedValue()
                              var data = Data(capacity: Int(size1 + size2))
                              buf1.withMemoryRebound(to: UInt8.self, capacity: Int(size1)) { buf in
                                  data.append(buf, count: Int(size1))
                              }
                              buf2.withMemoryRebound(to: UInt8.self, capacity: Int(size2)) { buf in
                                  data.append(buf, count: Int(size2))
                              }
                              if socket.delegate?.socket(socket, sendHook: data) ?? false {
                                  return size1 + size2
                              } else {
                                  return -1
                              }
                          },
                          context)
        self.options = options
        guard configure(.pre) else {
            throw makeSocketError()
        }
        var addrCopy = addr
        let result = withUnsafePointer(to: &addrCopy) { addrCopyPointer -> Int32 in
            srt_connect(
                socket,
                UnsafeRawPointer(addrCopyPointer).assumingMemoryBound(to: sockaddr.self),
                Int32(MemoryLayout.size(ofValue: addr))
            )
        }
        if result == SRT_ERROR {
            throw makeSocketError()
        }
        guard configure(.post) else {
            throw makeSocketError()
        }
        startRunning()
    }

    func doOutput(data: Data) {
        _ = sendmsg2(data)
    }

    func doOutputPointer(pointer: UnsafeRawBufferPointer, count: Int) {
        _ = sendmsg2pointer(pointer, count)
    }

    func close() {
        guard socket != SRT_INVALID_SOCK else {
            return
        }
        srt_close(socket)
        socket = SRT_INVALID_SOCK
    }

    func configure(_ binding: SRTSocketOption.Binding) -> Bool {
        let failures = SRTSocketOption.configure(socket, binding: binding, options: options)
        guard failures.isEmpty else {
            logger.error("configure failures: \(failures)")
            return false
        }
        return true
    }

    func bstats() -> Int32 {
        guard socket != SRT_INVALID_SOCK else {
            return SRT_ERROR
        }
        return srt_bstats(socket, &perf, 1)
    }

    func snd_data() -> Int32 {
        guard socket != SRT_INVALID_SOCK else {
            return SRT_ERROR
        }

        var sndData: Int32 = 0
        var size = Int32(MemoryLayout<Int32>.size)
        let result = withUnsafeMutablePointer(to: &sndData) { sndDataPointer -> Int32 in
            srt_getsockflag(
                socket,
                SRTO_SNDDATA,
                sndDataPointer,
                &size
            )
        }
        if result == SRT_ERROR {
            // To do: check result
        }
        return sndData
    }

    private func makeSocketError() -> String {
        return String(cString: srt_getlasterror_str())
    }

    @inline(__always)
    private func sendmsg2(_ data: Data) -> Int32 {
        return data.withUnsafeBytes { pointer in
            guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                logger.info("error buffer size \(data.count)")
                return SRT_ERROR
            }
            return srt_sendmsg2(socket, buffer, Int32(data.count), nil)
        }
    }

    @inline(__always)
    private func sendmsg2pointer(_ pointer: UnsafeRawBufferPointer, _ count: Int) -> Int32 {
        guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
            return SRT_ERROR
        }
        return srt_sendmsg2(socket, buffer, Int32(count), nil)
    }

    func startRunning() {
        guard !isRunning.value else {
            return
        }
        isRunning.mutate { $0 = true }
        DispatchQueue(label: "com.haishkinkit.HaishinKit.SRTSocket.runloop").async {
            repeat {
                self.status = srt_getsockstate(self.socket)
                usleep(3 * 10000)
            } while self.isRunning.value
        }
    }

    func stopRunning() {
        guard isRunning.value else {
            return
        }
        isRunning.mutate { $0 = false }
    }
}
