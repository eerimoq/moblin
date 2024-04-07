import Collections
import Foundation
import SwiftUI
import WatchConnectivity

private let previewTimeout = 5.0

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
    private var latestSpeedAndTotalDate = Date()
    @Published var audioLevel: Float = defaultAudioLevel
    private var latestAudioLevel = Date()
    @Published var preview: UIImage?
    @Published var showPreviewDisconnected = true
    private var latestPreviewDate = Date()
    var settings = WatchSettings()
    private var latestChatMessageDate = Date()
    private var numberOfNormalPostsInChat = 0
    private var nextExpectedWatchChatPostId = 1
    private var nextNonNormalChatLineId = -1
    var log: Deque<LogEntry> = []
    private var logId = 1
    var numberOfMessagesReceived = 0
    @Published var isLive = false
    @Published var isRecording = false
    @Published var isMuted = false

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
        let now = Date()
        if latestPreviewDate + previewTimeout < now, !showPreviewDisconnected {
            showPreviewDisconnected = true
        }
        if latestSpeedAndTotalDate + previewTimeout < now, speedAndTotal != noValue {
            speedAndTotal = noValue
        }
        if latestAudioLevel + previewTimeout < now, audioLevel != defaultAudioLevel {
            audioLevel = defaultAudioLevel
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
            latestChatMessageDate = Date()
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
        let now = Date()
        if latestChatMessageDate + 30 < now {
            appendRedLineMessage(message: message)
            if settings.chat.notificationOnMessage! {
                WKInterfaceDevice.current().play(.notification)
            }
        }
        latestChatMessageDate = now
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
        latestSpeedAndTotalDate = Date()
    }

    private func handleAudioLevel(_ data: Any) throws {
        guard let audioLevel = data as? Float else {
            logger.info("Invalid audio level message")
            return
        }
        self.audioLevel = audioLevel
        latestAudioLevel = Date()
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
    }

    private func handlePreview(_ data: Any) throws {
        guard let image = data as? Data else {
            logger.info("Invalid preview message")
            return
        }
        preview = UIImage(data: image)
        showPreviewDisconnected = false
        latestPreviewDate = Date()
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
                }
            } catch {}
        }
    }

    func sessionReachabilityDidChange(_: WCSession) {
        logger.debug("Reachability changed to \(WCSession.default.isReachable)")
    }
}
