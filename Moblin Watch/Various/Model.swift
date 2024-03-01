import Collections
import Foundation
import SwiftUI
import WatchConnectivity

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
    private var chatPostId = 0
    @Published var speedAndTotal = noValue
    @Published var audioLevel: Float = -160.0
    @Published var preview: UIImage?

    func setup() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            print("Not good!")
        }
    }

    private func handleChatMessage(value: Any) throws {
        guard let data = value as? Data else {
            return
        }
        let message = try JSONDecoder().decode(WatchProtocolChatMessage.self, from: data)
        DispatchQueue.main.async {
            self.chatPosts.prepend(ChatPost(id: self.chatPostId,
                                            user: message.user,
                                            userColor: message.userColor.color(),
                                            segments: message.segments.map { ChatPostSegment(text: $0) },
                                            timestamp: message.timestamp))
            self.chatPostId += 1
            if self.chatPosts.count > 10 {
                _ = self.chatPosts.popLast()
            }
        }
    }

    private func handleSpeedAndTotal(value: Any) throws {
        guard let speedAndTotal = value as? String else {
            return
        }
        DispatchQueue.main.async {
            self.speedAndTotal = speedAndTotal
        }
    }

    private func handleAudioLevel(value: Any) throws {
        guard let audioLevel = value as? Float else {
            return
        }
        DispatchQueue.main.async {
            self.audioLevel = audioLevel
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
        for entry in message {
            do {
                switch WatchMessage(rawValue: entry.key) {
                case .chatMessage:
                    try handleChatMessage(value: entry.value)
                case .speedAndTotal:
                    try handleSpeedAndTotal(value: entry.value)
                case .audioLevel:
                    try handleAudioLevel(value: entry.value)
                default:
                    print("Unknown message type \(entry.key)")
                }
            } catch {}
        }
    }

    func session(_: WCSession, didReceive file: WCSessionFile) {
        DispatchQueue.main.async {
            do {
                self.preview = try UIImage(data: Data(contentsOf: file.fileURL))
            } catch {
                print("preview not an image")
            }
        }
    }
}
