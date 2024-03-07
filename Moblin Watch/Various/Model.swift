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

struct ChatPost: Identifiable, Hashable {
    static func == (lhs: ChatPost, rhs: ChatPost) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

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
    private var previewTransfer = Data()
    private var nextPreviewTransferId: Int64 = -1
    var settings = WatchSettings()
    private var latestChatMessageDate = Date()
    private var numberOfNormalPostsInChat = 0
    private var nextExpectedWatchChatPostId = 1
    private var nextNonNormalChatLineId = -1
    var log: Deque<LogEntry> = []
    private var logId = 1
    var numberOfMessagesReceived = 0

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

    private func handleChatMessage(_ message: [String: Any]) throws {
        guard let data = message["data"] as? Data else {
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

    private func handleSpeedAndTotal(_ message: [String: Any]) throws {
        guard let speedAndTotal = message["data"] as? String else {
            logger.info("Invalid speed and total message")
            return
        }
        self.speedAndTotal = speedAndTotal
        latestSpeedAndTotalDate = Date()
    }

    private func handleAudioLevel(_ message: [String: Any]) throws {
        guard let audioLevel = message["data"] as? Float else {
            logger.info("Invalid audio level message")
            return
        }
        self.audioLevel = audioLevel
        latestAudioLevel = Date()
    }

    private func handleSettings(_ message: [String: Any]) throws {
        guard let settings = message["data"] as? Data else {
            logger.info("Invalid settings message")
            return
        }
        do {
            self.settings = try JSONDecoder().decode(WatchSettings.self, from: settings)
        } catch {}
    }

    private func handlePreview(_ message: [String: Any]) throws {
        guard let isFirst = message["isFirst"] as? Bool,
              let isLast = message["isLast"] as? Bool,
              let id = message["id"] as? Int64,
              let data = message["data"] as? Data
        else {
            logger.info("Invalid preview message")
            return
        }
        if isFirst {
            nextPreviewTransferId = id + 1
            previewTransfer = data
        } else if id == nextPreviewTransferId {
            previewTransfer += data
            nextPreviewTransferId += 1
        } else {
            nextPreviewTransferId = -1
            return
        }
        if isLast {
            preview = UIImage(data: previewTransfer)
            showPreviewDisconnected = false
            latestPreviewDate = Date()
            nextPreviewTransferId = -1
        }
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
        guard let type = message["type"] as? String else {
            logger.info("Message type missing")
            return
        }
        DispatchQueue.main.async {
            self.numberOfMessagesReceived += 1
            do {
                switch WatchMessage(rawValue: type) {
                case .speedAndTotal:
                    try self.handleSpeedAndTotal(message)
                case .settings:
                    try self.handleSettings(message)
                default:
                    logger.info("Unknown message type \(type)")
                }
            } catch {}
        }
    }

    func session(
        _: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: ([String: Any]) -> Void
    ) {
        guard let type = message["type"] as? String else {
            logger.info("Message type missing")
            return
        }
        DispatchQueue.main.async {
            self.numberOfMessagesReceived += 1
            do {
                switch WatchMessage(rawValue: type) {
                case .chatMessage:
                    try self.handleChatMessage(message)
                case .preview:
                    try self.handlePreview(message)
                case .audioLevel:
                    try self.handleAudioLevel(message)
                default:
                    logger.info("Unknown message type \(type)")
                }
            } catch {}
        }
        replyHandler([:])
    }

    func sessionReachabilityDidChange(_: WCSession) {
        logger.debug("Reachability changed to \(WCSession.default.isReachable)")
    }
}
