import WebKit

private func moblinScript() -> String {
    return loadStringResource(name: "moblin", ext: "js")
}

private enum PublishMessage: Codable {
    case videoPlaying(value: Bool)
}

private enum SubscribeTopic: Codable {
    case chat(prefix: String?)
}

private enum Message: Codable {
    case chat(message: ChatMessage)
}

private struct ChatMessage: Codable {
    // periphery:ignore
    var user: String
    // periphery:ignore
    var segments: [ChatPostSegment]

    init(message: ChatPost) {
        user = message.user ?? "???"
        segments = message.segments
    }
}

private enum MessageToMoblin: Codable {
    case ping
    case publish(message: PublishMessage)
    case subscribe(topic: SubscribeTopic)

    static func fromJson(data: String) throws -> MessageToMoblin {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MessageToMoblin.self, from: data)
    }
}

private enum MessageToBrowser: Codable {
    case message(data: Message)

    func toJson() -> String? {
        return try? String(bytes: JSONEncoder().encode(self), encoding: .utf8)
    }
}

private struct Chat {
    var prefix: String?
}

private class Subscriptions {
    var chat: Chat?
}

protocol BrowserEffectServerDelegate: AnyObject {
    func browserEffectServerVideoPlaying()
    func browserEffectServerVideoEnded()
}

class BrowserEffectServer: NSObject {
    weak var webView: WKWebView?
    private let subscriptions = Subscriptions()
    private let pingTimer = SimpleTimer(queue: .main)
    private var gotPing = true
    private let moblinAccess: Bool
    weak var delegate: BrowserEffectServerDelegate?

    init(configuration: WKWebViewConfiguration, moblinAccess: Bool) {
        self.moblinAccess = moblinAccess
        super.init()
        configuration.userContentController.addUserScript(.init(
            source: moblinScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        configuration.userContentController.add(self, name: "moblin")
    }

    func enable() {
        pingTimer.startPeriodic(interval: 5) { [weak self] in
            self?.handlePingTimer()
        }
    }

    func disable() {
        pingTimer.stop()
    }

    func sendChatMessage(post: ChatPost) {
        guard let chat = subscriptions.chat else {
            return
        }
        if let prefix = chat.prefix {
            guard let text = post.segments.first?.text, text.starts(with: prefix) else {
                return
            }
        }
        send(message: .message(data: .chat(message: .init(message: post))))
    }

    private func handlePingTimer() {
        if !gotPing {
            logger.info("browser-effect-server: Ping timeout")
            delegate?.browserEffectServerVideoEnded()
        }
        gotPing = false
    }

    private func send(message: MessageToBrowser) {
        guard let message = message.toJson() else {
            return
        }
        let data = message.utf8Data.base64EncodedString()
        webView?.evaluateJavaScript("""
        moblin.handleMessage(window.atob("\(data)"))
        """)
    }

    private func handleMessage(message: String) throws {
        do {
            switch try MessageToMoblin.fromJson(data: message) {
            case .ping:
                handlePing()
            case let .publish(message: message):
                handlePublish(message: message)
            case let .subscribe(topic: topic):
                handleSubscribe(topic: topic)
            }
        } catch {
            logger.info("browser-effect-server: Decode failed with error: \(error)")
        }
    }

    private func handlePing() {
        gotPing = true
    }

    private func handlePublish(message: PublishMessage) {
        switch message {
        case let .videoPlaying(videoPlaying):
            logger.debug("browser-effect-server: Got video playing: \(videoPlaying)")
            if videoPlaying {
                delegate?.browserEffectServerVideoPlaying()
            } else {
                delegate?.browserEffectServerVideoEnded()
            }
        }
    }

    private func handleSubscribe(topic: SubscribeTopic) {
        guard moblinAccess else {
            return
        }
        switch topic {
        case let .chat(prefix: prefix):
            subscriptions.chat = .init(prefix: prefix)
        }
    }
}

extension BrowserEffectServer: WKScriptMessageHandler {
    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let message = message.body as? String else {
            logger.info("browser-effect-server: Not a string message")
            return
        }
        DispatchQueue.main.async {
            try? self.handleMessage(message: message)
        }
    }
}
