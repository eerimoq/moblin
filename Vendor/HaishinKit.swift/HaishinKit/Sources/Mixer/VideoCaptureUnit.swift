import AVFoundation
import CoreImage

final class VideoCaptureUnit: CaptureUnit {
    enum Error: Swift.Error {
        case multiCamNotSupported
    }

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoCaptureUnit.lock")

    private(set) var isSuspended = false

    var mixerSettings: VideoMixerSettings {
        get {
            return videoMixer.settings
        }
        set {
            videoMixer.settings = newValue
        }
    }

    var inputFormats: [UInt8: CMFormatDescription] {
        return videoMixer.inputFormats
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    var isTorchEnabled = false {
        didSet {
            guard #available(tvOS 17.0, *) else {
                return
            }
            setTorchMode(isTorchEnabled ? .on : .off)
        }
    }
    #endif

    @available(tvOS 17.0, *)
    var hasDevice: Bool {
        !devices.lazy.filter { $0.value.device != nil }.isEmpty
    }

    #if os(iOS) || os(macOS)
    var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard videoOrientation != oldValue else {
                return
            }
            session.configuration { _ in
                for capture in devices.values {
                    capture.videoOrientation = videoOrientation
                }
            }
        }
    }
    #endif

    @AsyncStreamedFlow
    var inputs: AsyncStream<(UInt8, CMSampleBuffer)>

    @AsyncStreamedFlow
    var output: AsyncStream<CMSampleBuffer>

    var dynamicRangeMode: DynamicRangeMode = .sdr {
        didSet {
            guard dynamicRangeMode != oldValue, #available(tvOS 17.0, *) else {
                return
            }
            try? session.configuration { _ in
                for capture in devices.values {
                    try capture.setDynamicRangeMode(dynamicRangeMode)
                }
            }
        }
    }

    private lazy var videoMixer = {
        var videoMixer = VideoMixer<VideoCaptureUnit>()
        videoMixer.delegate = self
        return videoMixer
    }()

    #if os(tvOS)
    private var _devices: [UInt8: Any] = [:]
    @available(tvOS 17.0, *)
    var devices: [UInt8: VideoDeviceUnit] {
        get {
            _devices as! [UInt8: VideoDeviceUnit]
        }
        set {
            _devices = newValue
        }
    }
    #elseif os(iOS) || os(macOS) || os(visionOS)
    var devices: [UInt8: VideoDeviceUnit] = [:]
    #endif

    private let session: (any CaptureSessionConvertible)

    init(_ session: (some CaptureSessionConvertible)) {
        self.session = session
    }

    func append(_ track: UInt8, buffer: CMSampleBuffer) {
        videoMixer.append(track, sampleBuffer: buffer)
    }

    @available(tvOS 17.0, *)
    func attachVideo(_ track: UInt8, device: AVCaptureDevice?, configuration: VideoDeviceConfigurationBlock?) throws {
        try session.configuration { _ in
            session.detachCapture(devices[track])
            videoMixer.reset(track)
            devices[track] = nil
            if let device {
                if hasDevice && session.isMultiCamSessionEnabled == false {
                    throw Error.multiCamNotSupported
                }
                let capture = try VideoDeviceUnit(track, device: device)
                try? capture.setDynamicRangeMode(dynamicRangeMode)
                #if os(iOS) || os(macOS)
                capture.videoOrientation = videoOrientation
                #endif
                capture.setSampleBufferDelegate(self)
                try? configuration?(capture)
                session.attachCapture(capture)
                capture.apply()
                devices[track] = capture
            }
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    @available(tvOS 17.0, *)
    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        for capture in devices.values {
            capture.setTorchMode(torchMode)
        }
    }
    #endif

    @available(tvOS 17.0, *)
    func makeDataOutput(_ track: UInt8) -> VideoCaptureUnitDataOutput {
        return .init(track: track, videoMixer: videoMixer)
    }

    @available(tvOS 17.0, *)
    func suspend() {
        guard !isSuspended else {
            return
        }
        for capture in devices.values {
            session.detachCapture(capture)
        }
        isSuspended = true
    }

    @available(tvOS 17.0, *)
    func resume() {
        guard isSuspended else {
            return
        }
        for capture in devices.values {
            session.attachCapture(capture)
        }
        isSuspended = false
    }

    func finish() {
        _inputs.finish()
        _output.finish()
    }
}

extension VideoCaptureUnit: VideoMixerDelegate {
    // MARK: VideoMixerDelegate
    func videoMixer(_ videoMixer: VideoMixer<VideoCaptureUnit>, track: UInt8, didInput sampleBuffer: CMSampleBuffer) {
        _inputs.yield((track, sampleBuffer))
    }

    func videoMixer(_ videoMixer: VideoMixer<VideoCaptureUnit>, didOutput sampleBuffer: CMSampleBuffer) {
        _output.yield(sampleBuffer)
    }
}
