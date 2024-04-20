import AVFoundation
import Foundation
import libsrt

/// An object that provides the interface to control a one-way channel over a SRTConnection.
public class SRTStream: NetStream {
    private enum ReadyState: UInt8 {
        case initialized = 0
        case open = 1
        case play = 2
        case playing = 3
        case publish = 4
        case publishing = 5
        case closed = 6
    }

    private var name: String?
    private var action: (() -> Void)?
    private var keyValueObservations: [NSKeyValueObservation] = []
    private weak var connection: SRTConnection?

    private lazy var writer: TSWriter = {
        var writer = TSWriter()
        writer.delegate = self
        return writer
    }()

    private var readyState: ReadyState = .initialized {
        didSet {
            guard oldValue != readyState else {
                return
            }

            switch oldValue {
            case .publishing:
                writer.stopRunning()
                mixer.stopEncoding()
            case .playing:
                logger.info("Playing not implemented")
            default:
                break
            }

            switch readyState {
            case .play:
                logger.info("Play not implemented")
            case .publish:
                mixer.startEncoding(writer)
                mixer.startRunning()
                writer.startRunning()
                readyState = .publishing
            default:
                break
            }
        }
    }

    /// Creates a new SRTStream object.
    public init(_ connection: SRTConnection) {
        super.init()
        self.connection = connection
        self.connection?.removeStream()
        self.connection?.setStream(stream: self)
        let keyValueObservation = connection.observe(\.connected, options: [.new, .old]) { [weak self] _, _ in
            guard let self = self else {
                return
            }
            if connection.connected {
                self.action?()
                self.action = nil
            } else {
                self.readyState = .open
            }
        }
        keyValueObservations.append(keyValueObservation)
    }

    deinit {
        connection = nil
        keyValueObservations.removeAll()
    }

    override public func attachCamera(
        _ camera: AVCaptureDevice?,
        onError: ((Error) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil,
        replaceVideoCameraId: UUID? = nil
    ) {
        if camera == nil {
            writer.expectedMedias.remove(.video)
        } else {
            writer.expectedMedias.insert(.video)
        }
        super.attachCamera(
            camera,
            onError: onError,
            onSuccess: onSuccess,
            replaceVideoCameraId: replaceVideoCameraId
        )
    }

    override public func attachAudio(_ audio: AVCaptureDevice?, onError: ((Error) -> Void)? = nil) {
        if audio == nil {
            writer.expectedMedias.remove(.audio)
        } else {
            writer.expectedMedias.insert(.audio)
        }
        super.attachAudio(audio, onError: onError)
    }

    /// Sends streaming audio, video and data message from client.
    public func publish(_ name: String? = "") {
        lockQueue.async {
            guard let name else {
                switch self.readyState {
                case .publish, .publishing:
                    self.readyState = .open
                default:
                    break
                }
                return
            }
            if self.connection?.connected == true {
                self.readyState = .publish
            } else {
                self.action = { [weak self] in self?.publish(name) }
            }
        }
    }

    /// Stops playing or publishing and makes available other uses.
    public func close() {
        lockQueue.async {
            if self.readyState == .closed || self.readyState == .initialized {
                return
            }
            self.readyState = .closed
        }
    }
}

extension SRTStream: TSWriterDelegate {
    public func writer(_: TSWriter, doOutput data: Data) {
        guard readyState == .publishing else {
            return
        }
        connection?.socket?.doOutput(data: data)
    }

    public func writer(_: TSWriter, doOutputPointer pointer: UnsafeRawBufferPointer, count: Int) {
        guard readyState == .publishing else {
            return
        }
        connection?.socket?.doOutputPointer(pointer: pointer, count: count)
    }
}
