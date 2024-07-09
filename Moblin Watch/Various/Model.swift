import Collections
import Foundation
import SwiftUI
import WatchConnectivity

private var previewTimeout = Duration.seconds(5)

struct ChatPostSegment: Identifiable {
    var id = UUID()
    var text: String?
    var url: URL?
}

enum ChatPostKind {
    case normal
    case redLine
    case info
}

struct ChatPost: Identifiable {
    var id: Int
    var kind: ChatPostKind
    var user: String
    var userColor: Color
    var segments: [ChatPostSegment]
    var timestamp: String
}

struct LogEntry: Identifiable {
    var id: Int
    var message: String
}

class Model: NSObject, ObservableObject {
    @Published var chatPosts = Deque<ChatPost>()
    @Published var speedAndTotal = noValue
    private var latestSpeedAndTotalTime = ContinuousClock.now
    @Published var recordingLength = noValue
    private var latestRecordingLengthTime = ContinuousClock.now
    @Published var audioLevel: Float = defaultAudioLevel
    private var latestAudioLevelTime = ContinuousClock.now
    @Published var preview: UIImage?
    @Published var showPreviewDisconnected = true
    private var latestPreviewTime = ContinuousClock.now
    var settings = WatchSettings()
    private var latestChatMessageTime = ContinuousClock.now
    private var numberOfNormalPostsInChat = 0
    private var nextExpectedWatchChatPostId = 1
    private var nextNonNormalChatLineId = -1
    var log: Deque<LogEntry> = []
    private var logId = 1
    var numberOfMessagesReceived = 0
    @Published var isLive = false
    @Published var isRecording = false
    @Published var isMuted = false
    @Published var thermalState = ProcessInfo.ThermalState.nominal
    private var latestThermalStateTime = ContinuousClock.now

    func setup() {
        logger.handler = debugLog(message:)
        logger.debugEnabled = true
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        setupPeriodicTimers()
    }

    private func setupPeriodicTimers() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.updatePreview()
            self.keepAlive()
        })
    }

    func debugLog(message: String) {
        DispatchQueue.main.async {
            if self.log.count > 50 {
                self.log.removeFirst()
            }
            self.log.append(LogEntry(id: self.logId, message: message))
            self.logId += 1
        }
    }

    private func updatePreview() {
        let deadline = ContinuousClock.now - previewTimeout
        if latestPreviewTime < deadline, !showPreviewDisconnected {
            showPreviewDisconnected = true
        }
        if latestSpeedAndTotalTime < deadline, speedAndTotal != noValue {
            speedAndTotal = noValue
        }
        if latestRecordingLengthTime < deadline, recordingLength != noValue {
            recordingLength = noValue
        }
        if latestAudioLevelTime < deadline, audioLevel != defaultAudioLevel {
            audioLevel = defaultAudioLevel
        }
        if latestThermalStateTime < deadline, thermalState != ProcessInfo.ThermalState.nominal {
            thermalState = ProcessInfo.ThermalState.nominal
        }
    }

    private func makeUrl(url: String?) -> URL? {
        guard let url else {
            return nil
        }
        return URL(string: url)
    }

    private func appendInfoMessage(message: WatchProtocolChatMessage, segments: [ChatPostSegment]) {
        nextNonNormalChatLineId -= 1
        chatPosts.prepend(ChatPost(id: nextNonNormalChatLineId,
                                   kind: .info,
                                   user: "",
                                   userColor: .white,
                                   segments: segments,
                                   timestamp: message.timestamp))
    }

    private func appendRedLineMessage(message: WatchProtocolChatMessage) {
        nextNonNormalChatLineId -= 1
        chatPosts.prepend(ChatPost(id: nextNonNormalChatLineId,
                                   kind: .redLine,
                                   user: "",
                                   userColor: .red,
                                   segments: [],
                                   timestamp: message.timestamp))
    }

    private func handleChatMessage(_ data: Any) throws {
        guard let data = data as? Data else {
            logger.info("Invalid chat message message")
            return
        }
        let message = try JSONDecoder().decode(WatchProtocolChatMessage.self, from: data)
        // Latest received message is often retransmitted. Just ignore it if so (or likely so).
        if message.id == chatPosts.first?.id {
            return
        }
        if message.id < nextExpectedWatchChatPostId {
            nextExpectedWatchChatPostId = message.id
            chatPosts.removeAll()
            numberOfNormalPostsInChat = 0
            latestChatMessageTime = .now
            appendInfoMessage(message: message, segments: [
                .init(text: "Reconnected."),
            ])
        }
        let numberOfDiscardedChatMessages = message.id - nextExpectedWatchChatPostId
        if numberOfDiscardedChatMessages > 0 {
            appendInfoMessage(message: message, segments: [
                .init(text: String(numberOfDiscardedChatMessages)),
                .init(text: numberOfDiscardedChatMessages == 1 ? "message" : "messages"),
                .init(text: "discarded."),
            ])
        }
        nextExpectedWatchChatPostId = message.id + 1
        let now = ContinuousClock.now
        if latestChatMessageTime + .seconds(30) < now {
            appendRedLineMessage(message: message)
            if settings.chat.notificationOnMessage! {
                WKInterfaceDevice.current().play(.notification)
            }
        }
        latestChatMessageTime = now
        chatPosts.prepend(ChatPost(id: message.id,
                                   kind: .normal,
                                   user: message.user,
                                   userColor: message.userColor.color(),
                                   segments: message.segments.map { ChatPostSegment(
                                       text: $0.text,
                                       url: makeUrl(url: $0.url)
                                   ) },
                                   timestamp: message.timestamp))
        numberOfNormalPostsInChat += 1
        while numberOfNormalPostsInChat > maximumNumberOfWatchChatMessages {
            if chatPosts.popLast()?.kind == .normal {
                numberOfNormalPostsInChat -= 1
            }
        }
    }

    private func handleSpeedAndTotal(_ data: Any) throws {
        guard let speedAndTotal = data as? String else {
            logger.info("Invalid speed and total message")
            return
        }
        self.speedAndTotal = speedAndTotal
        latestSpeedAndTotalTime = .now
    }

    private func handleRecordingLength(_ data: Any) throws {
        guard let recordingLength = data as? String else {
            logger.info("Invalid recording length message")
            return
        }
        self.recordingLength = recordingLength
        latestRecordingLengthTime = .now
    }

    private func handleAudioLevel(_ data: Any) throws {
        guard let audioLevel = data as? Float else {
            logger.info("Invalid audio level message")
            return
        }
        self.audioLevel = audioLevel
        latestAudioLevelTime = .now
    }

    private func handleIsLive(_ data: Any) throws {
        guard let value = data as? Bool else {
            return
        }
        isLive = value
    }

    private func handleIsRecording(_ data: Any) throws {
        guard let value = data as? Bool else {
            return
        }
        isRecording = value
    }

    private func handleIsMuted(_ data: Any) throws {
        guard let value = data as? Bool else {
            return
        }
        isMuted = value
    }

    private func handleSettings(_ data: Any) throws {
        guard let settings = data as? Data else {
            logger.info("Invalid settings message")
            return
        }
        self.settings = try JSONDecoder().decode(WatchSettings.self, from: settings)
        if self.settings.chat.timestampEnabled == nil {
            self.settings.chat.timestampEnabled = false
        }
        if self.settings.chat.notificationOnMessage == nil {
            self.settings.chat.notificationOnMessage = false
        }
        if self.settings.show == nil {
            self.settings.show = .init()
        }
    }

    private func handleThermalState(_ data: Any) throws {
        guard let value = data as? Int,
              let thermalState = ProcessInfo.ThermalState(rawValue: value)
        else {
            logger.info("Invalid thermal state message")
            return
        }
        self.thermalState = thermalState
        latestThermalStateTime = .now
    }

    private func handlePreview(_ data: Any) throws {
        guard let image = data as? Data else {
            logger.info("Invalid preview message")
            return
        }
        preview = UIImage(data: image)
        showPreviewDisconnected = false
        latestPreviewTime = .now
    }

    func setIsLive(value: Bool) {
        let message = WatchMessageFromWatch.pack(type: .setIsLive, data: value)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func setIsRecording(value: Bool) {
        let message = WatchMessageFromWatch.pack(type: .setIsRecording, data: value)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func setIsMuted(value: Bool) {
        let message = WatchMessageFromWatch.pack(type: .setIsMuted, data: value)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func keepAlive() {
        let message = WatchMessageFromWatch.pack(type: .keepAlive, data: true)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func skipCurrentChatTextToSpeechMessage() {
        let message = WatchMessageFromWatch.pack(type: .skipCurrentChatTextToSpeechMessage, data: true)
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func isShowingStatusThermalState() -> Bool {
        return settings.show!.thermalState
    }

    func isShowingStatusAudioLevel() -> Bool {
        return settings.show!.audioLevel
    }

    func isShowingStatusBitrate() -> Bool {
        return settings.show!.speed && isLive
    }

    func isShowingStatusRecording() -> Bool {
        return isRecording
    }
}

extension Model: WCSessionDelegate {
    func session(
        _: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error _: Error?
    ) {
        switch activationState {
        case .activated:
            logger.info("Connectivity activated")
        case .inactive:
            logger.info("Connectivity inactive")
        case .notActivated:
            logger.info("Connectivity not activated")
        default:
            logger.info("Connectivity unknown")
        }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let (type, data) = WatchMessageToWatch.unpack(message) else {
            logger.info("watch: Invalid message")
            return
        }
        DispatchQueue.main.async {
            self.numberOfMessagesReceived += 1
            do {
                switch type {
                case .speedAndTotal:
                    try self.handleSpeedAndTotal(data)
                case .recordingLength:
                    try self.handleRecordingLength(data)
                case .settings:
                    try self.handleSettings(data)
                case .chatMessage:
                    try self.handleChatMessage(data)
                case .preview:
                    try self.handlePreview(data)
                case .audioLevel:
                    try self.handleAudioLevel(data)
                case .isLive:
                    try self.handleIsLive(data)
                case .isRecording:
                    try self.handleIsRecording(data)
                case .isMuted:
                    try self.handleIsMuted(data)
                case .thermalState:
                    try self.handleThermalState(data)
                }
            } catch {}
        }
    }

    func sessionReachabilityDidChange(_: WCSession) {
        logger.debug("Reachability changed to \(WCSession.default.isReachable)")
    }
}
