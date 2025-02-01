import AVFoundation
import Foundation
import libsrt

class SrtStream: NetStream {
    private enum ReadyState: UInt8 {
        case initialized = 0
        case open = 1
        case play = 2
        case playing = 3
        case publish = 4
        case publishing = 5
        case closed = 6
    }

    private var action: (() -> Void)?
    private var keyValueObservations: [NSKeyValueObservation] = []
    private weak var connection: SrtConnection?
    private let writer: MpegTsWriter

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

    init(_ connection: SrtConnection, timecodesEnabled: Bool) {
        writer = MpegTsWriter(timecodesEnabled: timecodesEnabled)
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
        writer.delegate = self
    }

    deinit {
        connection = nil
        keyValueObservations.removeAll()
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

    func publish(_ name: String? = "") {
        netStreamLockQueue.async {
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

    func close() {
        netStreamLockQueue.async {
            if self.readyState == .closed || self.readyState == .initialized {
                return
            }
            self.readyState = .closed
        }
    }
}

extension SrtStream: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data) {
        guard readyState == .publishing else {
            return
        }
        connection?.socket?.doOutput(data: data)
    }

    func writer(_: MpegTsWriter, doOutputPointer pointer: UnsafeRawBufferPointer, count: Int) {
        guard readyState == .publishing else {
            return
        }
        connection?.socket?.doOutputPointer(pointer: pointer, count: count)
    }
}
