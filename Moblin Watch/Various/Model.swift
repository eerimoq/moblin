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

    private func handleChatMessage(_ message: [String: Any]) throws {
        guard let data = message["data"] as? Data else {
            return
        }
        let message = try JSONDecoder().decode(WatchProtocolChatMessage.self, from: data)
        DispatchQueue.main.async {
            guard !self.chatPosts.contains(where: { $0.id == message.id }) else {
                return
            }
            self.chatPosts.prepend(ChatPost(id: message.id,
                                            user: message.user,
                                            userColor: message.userColor.color(),
                                            segments: message.segments.map { ChatPostSegment(text: $0) },
                                            timestamp: message.timestamp))
            if self.chatPosts.count > maximumNumberOfWatchChatMessages {
                _ = self.chatPosts.popLast()
            }
        }
    }

    private func handleSpeedAndTotal(_ message: [String: Any]) throws {
        guard let speedAndTotal = message["data"] as? String else {
            return
        }
        DispatchQueue.main.async {
            self.speedAndTotal = speedAndTotal
            self.latestSpeedAndTotalDate = Date()
        }
    }

    private func handleAudioLevel(_ message: [String: Any]) throws {
        guard let audioLevel = message["data"] as? Float else {
            return
        }
        DispatchQueue.main.async {
            self.audioLevel = audioLevel
            self.latestAudioLevel = Date()
        }
    }

    private func handleSettings(_ message: [String: Any]) throws {
        guard let settings = message["data"] as? Data else {
            return
        }
        DispatchQueue.main.async {
            do {
                self.settings = try JSONDecoder().decode(WatchSettings.self, from: settings)
            } catch {}
        }
    }

    private func handlePreview(_ message: [String: Any]) throws {
        guard let isFirst = message["isFirst"] as? Bool,
              let isLast = message["isLast"] as? Bool,
              let id = message["id"] as? Int64,
              let data = message["data"] as? Data
        else {
            return
        }
        DispatchQueue.main.async {
            if isFirst {
                self.nextPreviewTransferId = id + 1
                self.previewTransfer = data
            } else if id == self.nextPreviewTransferId {
                self.previewTransfer += data
                self.nextPreviewTransferId += 1
            } else {
                self.nextPreviewTransferId = -1
                return
            }
            if isLast {
                self.preview = UIImage(data: self.previewTransfer)
                self.showPreviewDisconnected = false
                self.latestPreviewDate = Date()
                self.nextPreviewTransferId = -1
            }
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
        do {
            switch WatchMessage(rawValue: type) {
            case .speedAndTotal:
                try handleSpeedAndTotal(message)
            case .audioLevel:
                try handleAudioLevel(message)
            case .settings:
                try handleSettings(message)
            default:
                print("Unknown message type \(type)")
            }
        } catch {}
    }

    func session(
        _: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: ([String: Any]) -> Void
    ) {
        guard let type = message["type"] as? String else {
            return
        }
        do {
            switch WatchMessage(rawValue: type) {
            case .chatMessage:
                try handleChatMessage(message)
            case .preview:
                try handlePreview(message)
            default:
                print("Unknown message type \(type)")
            }
        } catch {}
        replyHandler([:])
    }
}
