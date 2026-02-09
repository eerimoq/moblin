import Foundation
import libdatachannel

/// Delegate for receiving RTCDataChannel events.
public protocol RTCDataChannelDelegate: AnyObject {
    /// Called when the readyState of the data channel changes.
    /// - Parameters:
    ///   - dataChannel: The RTCDataChannel instance.
    ///   - readyState: The updated readyState.
    func dataChannel(_ dataChannel: RTCDataChannel, readyStateChanged readyState: RTCDataChannel.ReadyState)

    /// Called when a binary message is received.
    /// - Parameters:
    ///   - dataChannel: The RTCDataChannel instance.
    ///   - message: The received binary data.
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessage message: Data)

    /// Called when a text message is received.
    /// - Parameters:
    ///   - dataChannel: The RTCDataChannel instance.
    ///   - message: The received text message.
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessage message: String)
}

public final class RTCDataChannel: RTCChannel {
    /// Represents the ready state of an RTCDataChannel.
    public enum ReadyState {
        /// The data channel is being created and the connection is in progress.
        case connecting
        /// The data channel is fully established and ready to send and receive messages.
        case open
        /// The data channel is in the process of closing.
        case closing
        /// The data channel has been closed and can no longer be used.
        case closed
    }

    public weak var delegate: (any RTCDataChannelDelegate)?

    /// The label.
    public var label: String {
        do {
            return try CUtil.getString { buffer, size in
                rtcGetDataChannelLabel(id, buffer, size)
            }
        } catch {
            logger.warn(error)
            return ""
        }
    }

    /// The stream id.
    public var stream: Int {
        Int(rtcGetDataChannelStream(id))
    }

    public private(set) var readyState: ReadyState = .connecting {
        didSet {
            delegate?.dataChannel(self, readyStateChanged: readyState)
        }
    }

    let id: Int32

    init(id: Int32) throws {
        self.id = id
        try RTCError.check(id)
        do {
            try RTCError.check(rtcSetOpenCallback(id) { _, pointer in
                guard let pointer else { return }
                Unmanaged<RTCDataChannel>.fromOpaque(pointer).takeUnretainedValue().readyState = .open
            })
            try RTCError.check(rtcSetClosedCallback(id) { _, pointer in
                guard let pointer else { return }
                Unmanaged<RTCDataChannel>.fromOpaque(pointer).takeUnretainedValue().readyState = .connecting
            })
            try RTCError.check(rtcSetMessageCallback(id) { _, bytes, size, pointer in
                guard let bytes, let pointer else { return }
                if 0 <= size {
                    let data = Data(bytes: bytes, count: Int(size))
                    Unmanaged<RTCDataChannel>.fromOpaque(pointer).takeUnretainedValue().didReceiveMessage(data)
                } else {
                    Unmanaged<RTCDataChannel>.fromOpaque(pointer).takeUnretainedValue().didReceiveMessage(String(cString: bytes))
                }
            })
            try RTCError.check(rtcSetErrorCallback(id) { _, error, pointer in
                guard let error, let pointer else { return }
                Unmanaged<RTCDataChannel>.fromOpaque(pointer).takeUnretainedValue().errorOccurred(String(cString: error))
            })
            rtcSetUserPointer(id, Unmanaged.passUnretained(self).toOpaque())
        } catch {
            rtcDeleteDataChannel(id)
            throw error
        }
    }

    deinit {
        rtcDeleteDataChannel(id)
    }

    public func send(_ message: String) throws {
        guard let buffer = message.data(using: .utf8) else {
            return
        }
        try RTCError.check(buffer.withUnsafeBytes { pointer in
            return rtcSendMessage(id, pointer.bindMemory(to: CChar.self).baseAddress, -Int32(message.count))
        })
    }

    private func errorOccurred(_ error: String) {
        logger.warn(error)
    }

    private func didReceiveMessage(_ message: Data) {
        delegate?.dataChannel(self, didReceiveMessage: message)
    }

    private func didReceiveMessage(_ message: String) {
        delegate?.dataChannel(self, didReceiveMessage: message)
    }
}
