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

struct ChatPost: Identifiable {
    static func == (lhs: ChatPost, rhs: ChatPost) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: Int
    var user: String
    var userColor: Color
    var segments: [ChatPostSegment]
    var timestamp: String
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

    func setup() {
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

    private func handleChatMessage(_ message: [String: Any]) throws {
        guard let data = message["data"] as? Data else {
            return
        }
        let message = try JSONDecoder().decode(WatchProtocolChatMessage.self, from: data)
        guard !chatPosts.contains(where: { $0.id == message.id }) else {
            return
        }
        let now = Date()
        if settings.chat.notificationOnMessage! && latestChatMessageDate + 30 < now {
            WKInterfaceDevice.current().play(.notification)
        }
        latestChatMessageDate = now
        chatPosts.prepend(ChatPost(id: message.id,
                                   user: message.user,
                                   userColor: message.userColor.color(),
                                   segments: message.segments.map { ChatPostSegment(
                                       text: $0.text,
                                       url: makeUrl(url: $0.url)
                                   ) },
                                   timestamp: message.timestamp))
        if chatPosts.count > maximumNumberOfWatchChatMessages {
            _ = chatPosts.popLast()
        }
    }

    private func handleSpeedAndTotal(_ message: [String: Any]) throws {
        guard let speedAndTotal = message["data"] as? String else {
            return
        }
        self.speedAndTotal = speedAndTotal
        latestSpeedAndTotalDate = Date()
    }

    private func handleAudioLevel(_ message: [String: Any]) throws {
        guard let audioLevel = message["data"] as? Float else {
            return
        }
        self.audioLevel = audioLevel
        latestAudioLevel = Date()
    }

    private func handleSettings(_ message: [String: Any]) throws {
        guard let settings = message["data"] as? Data else {
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
            print("Connectivity activated")
        case .inactive:
            print("Connectivity inactive")
        case .notActivated:
            print("Connectivity not activated")
        default:
            print("Connectivity unknown state")
        }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else {
            return
        }
        DispatchQueue.main.async {
            do {
                switch WatchMessage(rawValue: type) {
                case .speedAndTotal:
                    try self.handleSpeedAndTotal(message)
                case .settings:
                    try self.handleSettings(message)
                default:
                    print("Unknown message type \(type)")
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
            return
        }
        DispatchQueue.main.async {
            do {
                switch WatchMessage(rawValue: type) {
                case .chatMessage:
                    try self.handleChatMessage(message)
                case .preview:
                    try self.handlePreview(message)
                case .audioLevel:
                    try self.handleAudioLevel(message)
                default:
                    print("Unknown message type \(type)")
                }
            } catch {}
        }
        replyHandler([:])
    }
}
