import AVFoundation
import Foundation
import libsrt

protocol SrtStreamDelegate: AnyObject {
    func srtStreamError()
}

private enum ReadyState: UInt8 {
    case initialized
    case publishing
}

private class SendHook {
    var closure: ((Data) -> Bool)?

    init(closure: ((Data) -> Bool)?) {
        self.closure = closure
    }
}

class SrtStream: NetStream {
    private let writer: MpegTsWriter
    private var sendHook = SendHook(closure: nil)
    private var options: [SrtSocketOption: String] = [:]
    private var perf = CBytePerfMon()
    private var socket: SRTSOCKET = SRT_INVALID_SOCK
    weak var srtStreamDelegate: SrtStreamDelegate?

    private var readyState: ReadyState = .initialized {
        didSet {
            guard oldValue != readyState else {
                return
            }
            logger.info("srt: State change \(oldValue) -> \(readyState)")
            switch oldValue {
            case .publishing:
                logger.info("srt: Stop publishing")
                writer.stopRunning()
                mixer.stopEncoding()
            default:
                break
            }
            switch readyState {
            case .publishing:
                logger.info("srt: Start publishing")
                mixer.startEncoding(writer)
                mixer.startRunning()
                writer.startRunning()
            default:
                break
            }
        }
    }

    init(timecodesEnabled: Bool, delegate: SrtStreamDelegate) {
        writer = MpegTsWriter(timecodesEnabled: timecodesEnabled)
        srtStreamDelegate = delegate
        super.init()
        writer.delegate = self
        srt_startup()
    }

    deinit {
        srt_cleanup()
    }

    override func attachCamera(
        _ camera: AVCaptureDevice?,
        _ cameraPreviewLayer: AVCaptureVideoPreviewLayer?,
        _ showCameraPreview: Bool,
        _ preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode,
        _ isVideoMirrored: Bool,
        _ ignoreFramesAfterAttachSeconds: Double,
        onError: ((Error) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil,
        replaceVideoCameraId: UUID? = nil
    ) {
        writer.expectedMedias.insert(.video)
        super.attachCamera(
            camera,
            cameraPreviewLayer,
            showCameraPreview,
            preferredVideoStabilizationMode,
            isVideoMirrored,
            ignoreFramesAfterAttachSeconds,
            onError: onError,
            onSuccess: onSuccess,
            replaceVideoCameraId: replaceVideoCameraId
        )
    }

    override func attachAudio(
        _ audio: AVCaptureDevice?,
        onError: ((Error) -> Void)? = nil,
        replaceAudioId: UUID? = nil
    ) {
        writer.expectedMedias.insert(.audio)
        super.attachAudio(audio, onError: onError, replaceAudioId: replaceAudioId)
    }

    func open(_ uri: URL?, sendHook: @escaping (Data) -> Bool) throws {
        guard let uri, uri.scheme == "srt", let host = uri.host, let port = uri.port else {
            return
        }
        self.sendHook = SendHook(closure: sendHook)
        socket = SRT_INVALID_SOCK
        try connect(sockaddrIn(host, port: UInt16(port)), SrtSocketOption.from(uri: uri))
    }

    func close() {
        netStreamLockQueue.async {
            self.readyState = .initialized
            guard self.socket != SRT_INVALID_SOCK else {
                return
            }
            srt_close(self.socket)
            self.socket = SRT_INVALID_SOCK
        }
    }

    func getPerformanceData() -> SrtPerformanceData {
        guard socket != SRT_INVALID_SOCK else {
            return .zero
        }
        _ = srt_bstats(socket, &perf, 1)
        return SrtPerformanceData(mon: perf)
    }

    func getSndData() -> Int32 {
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

    private func sockaddrIn(_ host: String, port: UInt16) -> sockaddr_in {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = CFSwapInt16BigToHost(port)
        if inet_pton(AF_INET, host, &addr.sin_addr) == 1 {
            return addr
        }
        guard let hostent = gethostbyname(host), hostent.pointee.h_addrtype == AF_INET else {
            return addr
        }
        addr.sin_addr = UnsafeRawPointer(hostent.pointee.h_addr_list[0]!)
            .assumingMemoryBound(to: in_addr.self).pointee
        return addr
    }

    private func connect(_ addr: sockaddr_in, _ options: [SrtSocketOption: String]) throws {
        guard socket == SRT_INVALID_SOCK else {
            return
        }
        socket = srt_create_socket()
        if socket == SRT_INVALID_SOCK {
            throw makeSocketError()
        }
        let context = Unmanaged.passRetained(sendHook).toOpaque()
        srt_send_callback(socket,
                          { context, _, buf1, size1, buf2, size2 in
                              guard let context, let buf1, let buf2 else {
                                  return -1
                              }
                              let sendHook: SendHook = Unmanaged.fromOpaque(context).takeUnretainedValue()
                              var data = Data(capacity: Int(size1 + size2))
                              buf1.withMemoryRebound(to: UInt8.self, capacity: Int(size1)) { buf in
                                  data.append(buf, count: Int(size1))
                              }
                              buf2.withMemoryRebound(to: UInt8.self, capacity: Int(size2)) { buf in
                                  data.append(buf, count: Int(size2))
                              }
                              if sendHook.closure?(data) ?? false {
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
        readyState = .publishing
    }

    private func configure(_ binding: SrtSocketOption.Binding) -> Bool {
        let failures = SrtSocketOption.configure(socket, binding: binding, options: options)
        guard failures.isEmpty else {
            logger.error("srt: configure failures: \(failures)")
            return false
        }
        return true
    }

    private func makeSocketError() -> String {
        return String(cString: srt_getlasterror_str())
    }
}

extension SrtStream: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data) {
        if data.withUnsafeBytes({ pointer in
            guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                logger.info("srt: error buffer size \(data.count)")
                return SRT_ERROR
            }
            return srt_sendmsg2(socket, buffer, Int32(data.count), nil)
        }) != data.count {
            netStreamLockQueue.async {
                self.readyState = .initialized
                self.srtStreamDelegate?.srtStreamError()
            }
        }
    }

    func writer(_: MpegTsWriter, doOutputPointer pointer: UnsafeRawBufferPointer, count: Int) {
        guard let buffer = pointer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
            return
        }
        if srt_sendmsg2(socket, buffer, Int32(count), nil) != count {
            netStreamLockQueue.async {
                self.readyState = .initialized
                self.srtStreamDelegate?.srtStreamError()
            }
        }
    }
}
