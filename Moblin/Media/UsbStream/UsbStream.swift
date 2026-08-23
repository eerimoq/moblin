import AVFAudio
import CoreMedia
import Foundation
import Network
import UIKit

private let usbStreamQueue = DispatchQueue(label: "com.eerimoq.usb-stream")

protocol UsbStreamDelegate: AnyObject {
    func usbStreamOnConnected()
    func usbStreamOnDisconnected(reason: String)
    func usbStreamStartEncoding(_ delegate: any AudioEncoderDelegate & VideoEncoderDelegate)
    func usbStreamStopEncoding(_ delegate: any AudioEncoderDelegate & VideoEncoderDelegate)
}

final class UsbStream: NSObject, @unchecked Sendable {
    private weak var delegate: (any UsbStreamDelegate)?
    private var listener: NWListener?
    private var connection: NWConnection?
    private var reader = UsbStreamMessageReader()
    private var connectedAt: ContinuousClock.Instant?
    private var acceptedAt: ContinuousClock.Instant?
    private var encoding = false
    private var port: UInt16 = 0
    private var bitrateStats = BitrateStats()
    private var outstandingByteCount = 0
    private var congestedAt: ContinuousClock.Instant?
    private var dropUntilSync = false
    private var audioSupported = false
    private var periodicTimer = SimpleTimer(queue: usbStreamQueue)

    init(delegate: any UsbStreamDelegate) {
        self.delegate = delegate
        super.init()
    }

    func start(port: UInt16) {
        usbStreamQueue.async {
            self.port = port
            self.setupListener()
            self.setupPeriodicTimer()
        }
    }

    func stop() {
        usbStreamQueue.async {
            self.periodicTimer.stop()
            self.closeConnection(reason: "Stopping")
            self.listener?.stateUpdateHandler = nil
            self.listener?.newConnectionHandler = nil
            self.listener?.cancel()
            self.listener = nil
        }
    }

    func getSpeed() -> UInt64 {
        usbStreamQueue.sync {
            8 * bitrateStats.update().speed
        }
    }

    func getTotalByteCount() -> Int64 {
        usbStreamQueue.sync {
            Int64(bitrateStats.totalBytes)
        }
    }

    private func setupListener() {
        let options = NWProtocolTCP.Options()
        options.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: options)
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: port) ?? 7777
        )
        parameters.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: parameters)
        } catch {
            logger.info("usb-stream: Failed to create listener with error \(error)")
            return
        }
        listener?.stateUpdateHandler = handleListenerStateChange(to:)
        listener?.newConnectionHandler = handleNewListenerConnection(connection:)
        listener?.start(queue: usbStreamQueue)
    }

    private func setupPeriodicTimer() {
        periodicTimer.startPeriodic(interval: 1) {
            switch self.listener?.state {
            case .failed:
                self.setupListener()
            default:
                break
            }
            if let acceptedAt = self.acceptedAt, self.connectedAt == nil,
               acceptedAt.duration(to: .now) > .seconds(5)
            {
                self.closeConnection(reason: "Hello timeout")
            }
            if let congestedAt = self.congestedAt, congestedAt.duration(to: .now) > .seconds(5) {
                self.closeConnection(reason: "Host is not reading")
            }
        }
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        logger.info("usb-stream: Listener state change to \(state)")
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        if self.connection != nil {
            closeConnection(reason: "Another host connected")
        }
        logger.info("usb-stream: Host connected")
        self.connection = connection
        reader = UsbStreamMessageReader()
        acceptedAt = .now
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateChange(connection, state)
        }
        connection.start(queue: usbStreamQueue)
        receive(connection)
    }

    private func handleConnectionStateChange(_ connection: NWConnection, _ state: NWConnection.State) {
        guard connection === self.connection else {
            return
        }
        switch state {
        case let .failed(error):
            closeConnection(reason: "Connection failed with error \(error)")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isDone,
            error in
            guard let self, connection === self.connection else {
                return
            }
            if let data, !data.isEmpty {
                guard handleReceived(data) else {
                    return
                }
            }
            if let error {
                closeConnection(reason: "Receive failed with error \(error)")
                return
            }
            if isDone {
                closeConnection(reason: "Host closed the connection")
                return
            }
            receive(connection)
        }
    }

    private func handleReceived(_ data: Data) -> Bool {
        reader.append(data)
        do {
            while let (type, payload) = try reader.read() {
                try handleMessage(type, payload)
            }
        } catch {
            closeConnection(reason: "Protocol error \(error)")
            return false
        }
        return true
    }

    private func handleMessage(_ type: UsbStreamMessageType, _ payload: Data) throws {
        switch type {
        case .hostHello:
            try handleHostHello(payload)
        default:
            logger.info("usb-stream: Ignoring message type \(type)")
        }
    }

    private func handleHostHello(_ payload: Data) throws {
        guard connectedAt == nil else {
            return
        }
        try unpackUsbStreamHostHello(payload)
        connectedAt = .now
        let info = UsbStreamDeviceInfo(name: UIDevice.current.name, version: appVersion())
        send(packUsbStreamDeviceHello(info))
        logger.info("usb-stream: Host said hello")
        delegate?.usbStreamOnConnected()
        encoding = true
        delegate?.usbStreamStartEncoding(self)
    }

    private func closeConnection(reason: String) {
        guard let connection else {
            return
        }
        logger.info("usb-stream: Closing connection. \(reason).")
        if encoding {
            encoding = false
            delegate?.usbStreamStopEncoding(self)
        }
        connection.stateUpdateHandler = nil
        connection.cancel()
        self.connection = nil
        let wasConnected = connectedAt != nil
        connectedAt = nil
        acceptedAt = nil
        congestedAt = nil
        outstandingByteCount = 0
        dropUntilSync = false
        audioSupported = false
        if wasConnected {
            delegate?.usbStreamOnDisconnected(reason: reason)
        }
    }

    private func send(_ data: Data) {
        guard let connection else {
            return
        }
        outstandingByteCount += data.count
        bitrateStats.add(bytesTransferred: data.count)
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            guard let self, connection === self.connection else {
                return
            }
            outstandingByteCount -= data.count
            if outstandingByteCount < 1_000_000 {
                congestedAt = nil
            }
        })
    }

    private func isCongested() -> Bool {
        guard outstandingByteCount > 1_000_000 else {
            return false
        }
        if congestedAt == nil {
            congestedAt = .now
            logger.info("usb-stream: Host is falling behind. Dropping video frames.")
        }
        return true
    }

    private func toMicroseconds(_ presentationTimeStamp: CMTime) -> UInt64? {
        let scaled = CMTimeConvertScale(presentationTimeStamp,
                                        timescale: 1_000_000,
                                        method: .roundTowardZero)
        guard scaled.isValid, scaled.value >= 0 else {
            return nil
        }
        return UInt64(scaled.value)
    }

    private func handleVideoEncoderOutputFormat(_ formatDescription: CMFormatDescription) {
        guard connectedAt != nil else {
            return
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        switch formatDescription.mediaSubType {
        case .h264:
            guard let record = MpegTsVideoConfigAvc.getAvcC(formatDescription) else {
                return
            }
            send(packUsbStreamVideoConfig(codec: .h264,
                                          width: UInt16(dimensions.width),
                                          height: UInt16(dimensions.height),
                                          configurationRecord: record))
        case .hevc:
            guard let record = MpegTsVideoConfigHevc.getHvcC(formatDescription) else {
                return
            }
            send(packUsbStreamVideoConfig(codec: .hevc,
                                          width: UInt16(dimensions.width),
                                          height: UInt16(dimensions.height),
                                          configurationRecord: record))
        default:
            logger.info("usb-stream: Unsupported video codec \(formatDescription.mediaSubType)")
        }
    }

    private func handleVideoEncoderOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard connectedAt != nil else {
            return
        }
        guard let presentationTimeStamp = toMicroseconds(sampleBuffer.presentationTimeStamp) else {
            return
        }
        let isSync = sampleBuffer.getIsSync()
        if isCongested() {
            dropUntilSync = true
            return
        }
        if dropUntilSync {
            guard isSync else {
                return
            }
            dropUntilSync = false
        }
        guard let (buffer, length) = sampleBuffer.dataBuffer?.getDataPointer(), length > 0 else {
            return
        }
        send(packUsbStreamVideoFrame(presentationTimeStamp: presentationTimeStamp,
                                     isSync: isSync,
                                     units: Data(bytes: buffer, count: length)))
    }

    private func handleAudioEncoderOutputFormat(_ format: AVAudioFormat) {
        guard connectedAt != nil else {
            return
        }
        guard let description = format.formatDescription.audioStreamBasicDescription else {
            return
        }
        audioSupported = description.mFormatID == kAudioFormatMPEG4AAC
        guard audioSupported else {
            logger.info("usb-stream: Only AAC audio is supported. Streaming video only.")
            return
        }
        let config = MpegTsAudioConfig(formatDescription: format.formatDescription)
        send(packUsbStreamAudioConfig(codec: .aac,
                                      sampleRate: UInt32(format.sampleRate),
                                      channels: UInt8(format.channelCount),
                                      configurationRecord: config.encode()))
    }

    private func handleAudioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer,
                                                _ presentationTimeStamp: CMTime)
    {
        guard connectedAt != nil, audioSupported, buffer.byteLength > 0 else {
            return
        }
        guard let presentationTimeStamp = toMicroseconds(presentationTimeStamp) else {
            return
        }
        let data = Data(bytes: buffer.data, count: Int(buffer.byteLength))
        guard buffer.packetCount > 0, let descriptions = buffer.packetDescriptions else {
            send(packUsbStreamAudioFrame(presentationTimeStamp: presentationTimeStamp, unit: data))
            return
        }
        for index in 0 ..< Int(buffer.packetCount) {
            let description = descriptions[index]
            let offset = Int(description.mStartOffset)
            let size = Int(description.mDataByteSize)
            guard size > 0, offset >= 0, offset + size <= data.count else {
                continue
            }
            send(packUsbStreamAudioFrame(presentationTimeStamp: presentationTimeStamp,
                                         unit: data.subdata(in: offset ..< offset + size)))
        }
    }
}

extension UsbStream: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_ format: AVAudioFormat) {
        usbStreamQueue.async {
            self.handleAudioEncoderOutputFormat(format)
        }
    }

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        usbStreamQueue.async {
            self.handleAudioEncoderOutputBuffer(buffer, presentationTimeStamp)
        }
    }
}

extension UsbStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_: VideoEncoder, _ formatDescription: CMFormatDescription) {
        usbStreamQueue.async {
            self.handleVideoEncoderOutputFormat(formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _: CMTime)
    {
        usbStreamQueue.async {
            self.handleVideoEncoderOutputSampleBuffer(sampleBuffer)
        }
    }
}
