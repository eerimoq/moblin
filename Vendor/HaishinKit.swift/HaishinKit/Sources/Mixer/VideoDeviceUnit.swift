import AVFoundation
import Foundation

/// Configuration calback block for a VideoDeviceUnit.
@available(tvOS 17.0, *)
public typealias VideoDeviceConfigurationBlock = @Sendable (VideoDeviceUnit) throws -> Void

/// An object that provides the interface to control the AVCaptureDevice's transport behavior.
@available(tvOS 17.0, *)
public final class VideoDeviceUnit: DeviceUnit {
    /// The error domain codes.
    public enum Error: Swift.Error {
        /// The frameRate isn’t supported.
        case unsupportedFrameRate
        /// The dynamic range mode isn't supported.
        case unsupportedDynamicRangeMode(_ mode: DynamicRangeMode)
    }

    /// The output type that this capture video data output..
    public typealias Output = AVCaptureVideoDataOutput

    /// The default color format.
    public static let colorFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

    /// The device object.
    public private(set) var device: AVCaptureDevice?

    /// The frame rate for capturing video frame.
    public private(set) var frameRate = MediaMixer.defaultFrameRate

    /// Specifies the video capture color format.
    public var colorFormat = VideoDeviceUnit.colorFormat

    /// The track number.
    public let track: UInt8
    /// The input data to a cupture session.
    public private(set) var input: AVCaptureInput?
    /// The output data to a sample buffers.
    public private(set) var output: Output? {
        didSet {
            oldValue?.setSampleBufferDelegate(nil, queue: nil)
            guard let output else {
                return
            }
            output.alwaysDiscardsLateVideoFrames = true
        }
    }
    /// The connection from a capture input to a capture output.
    public private(set) var connection: AVCaptureConnection?

    #if os(iOS) || os(macOS)
    /// Specifies the videoOrientation indicates whether to rotate the video flowing through the connection to a given orientation.
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            output?.connections.filter { $0.isVideoOrientationSupported }.forEach {
                $0.videoOrientation = videoOrientation
            }
        }
    }
    #endif

    #if os(iOS) || os(macOS) || os(tvOS)
    /// Spcifies the video mirroed indicates whether the video flowing through the connection should be mirrored about its vertical axis.
    public var isVideoMirrored = false {
        didSet {
            output?.connections.filter { $0.isVideoMirroringSupported }.forEach {
                $0.isVideoMirrored = isVideoMirrored
            }
        }
    }
    #endif

    #if os(iOS)
    /// Specifies the preferredVideoStabilizationMode most appropriate for use with the connection.
    public var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            output?.connections.filter { $0.isVideoStabilizationSupported }.forEach {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }
    #endif

    private var dynamicRangeMode: DynamicRangeMode = .sdr
    private var dataOutput: VideoCaptureUnitDataOutput?

    init(_ track: UInt8, device: AVCaptureDevice) throws {
        self.track = track
        input = try AVCaptureDeviceInput(device: device)
        self.output = AVCaptureVideoDataOutput()
        self.device = device
        #if os(iOS)
        if let output, let port = input?.ports.first(where: { $0.mediaType == .video && $0.sourceDeviceType == device.deviceType && $0.sourceDevicePosition == device.position }) {
            connection = AVCaptureConnection(inputPorts: [port], output: output)
        } else {
            connection = nil
        }
        #elseif os(tvOS) || os(macOS)
        if let output, let port = input?.ports.first(where: { $0.mediaType == .video }) {
            connection = AVCaptureConnection(inputPorts: [port], output: output)
        } else {
            connection = nil
        }
        #endif
    }

    /// Sets the frame rate of a device capture.
    public func setFrameRate(_ frameRate: Float64) throws {
        guard let device else {
            return
        }
        try device.lockForConfiguration()
        defer {
            device.unlockForConfiguration()
        }
        if device.activeFormat.isFrameRateSupported(frameRate) {
            device.activeVideoMinFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
        } else {
            if let format = device.videoFormat(
                width: device.activeFormat.formatDescription.dimensions.width,
                height: device.activeFormat.formatDescription.dimensions.height,
                frameRate: frameRate,
                isMultiCamSupported: device.activeFormat.isMultiCamSupported
            ) {
                device.activeFormat = format
                device.activeVideoMinFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
                device.activeVideoMaxFrameDuration = CMTime(value: 100, timescale: CMTimeScale(100 * frameRate))
            } else {
                throw Error.unsupportedFrameRate
            }
        }
        self.frameRate = frameRate
    }

    func setDynamicRangeMode(_ dynamicRangeMode: DynamicRangeMode) throws {
        guard let device, self.dynamicRangeMode != dynamicRangeMode else {
            return
        }
        try device.lockForConfiguration()
        defer {
            device.unlockForConfiguration()
        }
        let activeFormat = device.activeFormat
        if let format = device.formats.filter({ $0.formatDescription.dimensions.size == activeFormat.formatDescription.dimensions.size }).first(where: { $0.formatDescription.mediaSubType.rawValue == dynamicRangeMode.videoFormat }) {
            device.activeFormat = format
            self.dynamicRangeMode = dynamicRangeMode
        } else {
            throw Error.unsupportedDynamicRangeMode(dynamicRangeMode)
        }
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        guard let device, device.isTorchModeSupported(torchMode) else {
            return
        }
        do {
            try device.lockForConfiguration()
            defer {
                device.unlockForConfiguration()
            }
            device.torchMode = torchMode
        } catch {
            logger.error("while setting torch:", error)
        }
    }
    #endif

    func setSampleBufferDelegate(_ videoUnit: VideoCaptureUnit?) {
        dataOutput = videoUnit?.makeDataOutput(track)
        output?.setSampleBufferDelegate(dataOutput, queue: videoUnit?.lockQueue)
    }

    func apply() {
        #if os(iOS) || os(tvOS) || os(macOS)
        output?.connections.forEach {
            if $0.isVideoMirroringSupported {
                $0.isVideoMirrored = isVideoMirrored
            }
            #if os(iOS) || os(macOS)
            if $0.isVideoOrientationSupported {
                $0.videoOrientation = videoOrientation
            }
            #endif
            #if os(iOS)
            if $0.isVideoStabilizationSupported {
                $0.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
            #endif
        }
        #endif
    }
}

@available(tvOS 17.0, *)
final class VideoCaptureUnitDataOutput: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let track: UInt8
    private let videoMixer: VideoMixer<VideoCaptureUnit>

    init(track: UInt8, videoMixer: VideoMixer<VideoCaptureUnit>) {
        self.track = track
        self.videoMixer = videoMixer
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        videoMixer.append(track, sampleBuffer: sampleBuffer)
    }
}
