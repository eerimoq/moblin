import AVFAudio
import CoreMedia
import Foundation
import Network
import UIKit

private let mobcamStreamQueue = DispatchQueue(label: "com.eerimoq.mobcam-stream")
private let congestionThresholeBytes = 10_000_000

protocol MobcamStreamDelegate: AnyObject {
    func mobcamStreamOnConnected()
    func mobcamStreamOnDisconnected(reason: String)
    func mobcamStreamStartEncoding(_ delegate: any AudioEncoderDelegate & VideoEncoderDelegate)
    func mobcamStreamStopEncoding(_ delegate: any AudioEncoderDelegate & VideoEncoderDelegate)
}

final class MobcamStream: @unchecked Sendable {
    private weak var delegate: (any MobcamStreamDelegate)?
    private var listener: NWListener?
    private var connection: NWConnection?
    private var reader = MobcamStreamMessageReader()
    private var connectedAt: ContinuousClock.Instant?
    private var acceptedAt: ContinuousClock.Instant?
    private var encoding = false
    private var port: UInt16 = 0
    private var bitrateStats = BitrateStats()
    private var outstandingByteCount = 0
    private var congestedAt: ContinuousClock.Instant?
    private var dropUntilSync = false
    private var audioSupported = false
    private var periodicTimer = SimpleTimer(queue: mobcamStreamQueue)

    init(delegate: any MobcamStreamDelegate) {
        self.delegate = delegate
    }

    func start(port: UInt16) {
        mobcamStreamQueue.async {
            self.port = port
            self.setupListener()
            self.setupPeriodicTimer()
        }
    }

    func stop() {
        mobcamStreamQueue.async {
            self.periodicTimer.stop()
            self.closeConnection(reason: "Stopping")
            self.stopListener()
        }
    }

    func getSpeed() -> UInt64 {
        mobcamStreamQueue.sync {
            8 * bitrateStats.update().speed
        }
    }

    func getTotalByteCount() -> Int64 {
        mobcamStreamQueue.sync {
            Int64(bitrateStats.totalBytes)
        }
    }

    private func stopListener() {
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
    }

    private func setupListener() {
        stopListener()
        let options = NWProtocolTCP.Options()
        options.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: options)
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: port) ?? .init(integerLiteral: DefaultTcpPorts.mobcamStream)
        )
        parameters.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: parameters)
        } catch {
            logger.info("mobcam-stream: Failed to create listener with error \(error)")
            return
        }
        listener?.stateUpdateHandler = handleListenerStateChange(to:)
        listener?.newConnectionHandler = handleNewListenerConnection(connection:)
        listener?.start(queue: mobcamStreamQueue)
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
        logger.info("mobcam-stream: Listener state change to \(state)")
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        if self.connection != nil {
            closeConnection(reason: "Another host connected")
        }
        logger.info("mobcam-stream: Host connected")
        self.connection = connection
        reader = MobcamStreamMessageReader()
        acceptedAt = .now
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateChange(connection, state)
        }
        connection.start(queue: mobcamStreamQueue)
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

    private func handleMessage(_ type: MobcamStreamMessageType, _ payload: Data) throws {
        switch type {
        case .hostHello:
            try handleHostHello(payload)
        default:
            logger.info("mobcam-stream: Ignoring message type \(type)")
        }
    }

    private func handleHostHello(_ payload: Data) throws {
        guard connectedAt == nil else {
            return
        }
        try unpackMobcamStreamHostHello(payload)
        connectedAt = .now
        let info = MobcamStreamDeviceInfo(name: UIDevice.current.name, version: appVersion())
        send(packMobcamStreamDeviceHello(info))
        logger.info("mobcam-stream: Host said hello")
        delegate?.mobcamStreamOnConnected()
        encoding = true
        delegate?.mobcamStreamStartEncoding(self)
    }

    private func closeConnection(reason: String) {
        guard let connection else {
            return
        }
        logger.info("mobcam-stream: Closing connection. \(reason).")
        if encoding {
            encoding = false
            delegate?.mobcamStreamStopEncoding(self)
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
            delegate?.mobcamStreamOnDisconnected(reason: reason)
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
            if outstandingByteCount < congestionThresholeBytes {
                congestedAt = nil
            }
        })
    }

    private func isCongested() -> Bool {
        guard outstandingByteCount > congestionThresholeBytes else {
            return false
        }
        if congestedAt == nil {
            congestedAt = .now
            logger.info("mobcam-stream: Host is falling behind. Dropping video frames.")
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
            send(packMobcamStreamVideoConfig(codec: .h264,
                                             width: UInt16(dimensions.width),
                                             height: UInt16(dimensions.height),
                                             configurationRecord: record))
        case .hevc:
            guard let record = MpegTsVideoConfigHevc.getHvcC(formatDescription) else {
                return
            }
            send(packMobcamStreamVideoConfig(codec: .hevc,
                                             width: UInt16(dimensions.width),
                                             height: UInt16(dimensions.height),
                                             configurationRecord: record))
        default:
            logger.info("mobcam-stream: Unsupported video codec \(formatDescription.mediaSubType)")
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
        send(packMobcamStreamVideoFrame(presentationTimeStamp: presentationTimeStamp,
                                        isSync: isSync,
                                        units: UnsafeRawBufferPointer(start: buffer, count: length)))
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
            logger.info("mobcam-stream: Only AAC audio is supported. Streaming video only.")
            return
        }
        let config = MpegTsAudioConfig(formatDescription: format.formatDescription)
        send(packMobcamStreamAudioConfig(codec: .aac,
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
        let units = UnsafeRawBufferPointer(start: buffer.data, count: Int(buffer.byteLength))
        guard buffer.packetCount > 0, let descriptions = buffer.packetDescriptions else {
            send(packMobcamStreamAudioFrame(presentationTimeStamp: presentationTimeStamp, unit: units))
            return
        }
        for index in 0 ..< Int(buffer.packetCount) {
            let description = descriptions[index]
            let offset = Int(description.mStartOffset)
            let size = Int(description.mDataByteSize)
            guard size > 0, offset >= 0, offset + size <= units.count else {
                continue
            }
            let unit = UnsafeRawBufferPointer(rebasing: units[offset ..< offset + size])
            send(packMobcamStreamAudioFrame(presentationTimeStamp: presentationTimeStamp, unit: unit))
        }
    }
}

extension MobcamStream: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_ format: AVAudioFormat) {
        mobcamStreamQueue.async {
            self.handleAudioEncoderOutputFormat(format)
        }
    }

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        mobcamStreamQueue.async {
            self.handleAudioEncoderOutputBuffer(buffer, presentationTimeStamp)
        }
    }
}

extension MobcamStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_: VideoEncoder, _ formatDescription: CMFormatDescription) {
        mobcamStreamQueue.async {
            self.handleVideoEncoderOutputFormat(formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _: CMTime)
    {
        mobcamStreamQueue.async {
            self.handleVideoEncoderOutputSampleBuffer(sampleBuffer)
        }
    }
}
