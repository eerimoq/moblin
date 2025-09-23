import WebKit

private let moblinScript = """
class Moblin {
  constructor() {
    this.onmessage = null;
  }

  subscribe(topic) {
    this.send({ subscribe: { topic: topic } });
  }

  handleMessage(message) {
    if (this.onmessage) {
      this.onmessage(JSON.parse(message).message.data);
    }
  }

  send(message) {
    window.webkit.messageHandlers.moblin.postMessage(JSON.stringify(message));
  }
}

const moblin = new Moblin();
"""

private enum SubscribeTopic: Codable {
    case chat(prefix: String?)
}

private enum Message: Codable {
    case chat(message: ChatMessage)
}

private struct ChatMessage: Codable {
    var user: String
    var segments: [ChatPostSegment]

    init(message: ChatPost) {
        user = message.user ?? "???"
        segments = message.segments
    }
}

private enum MessageToMoblin: Codable {
    case subscribe(topic: SubscribeTopic)

    func toJson() -> String? {
        do {
            return try String(bytes: JSONEncoder().encode(self), encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func fromJson(data: String) throws -> MessageToMoblin {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MessageToMoblin.self, from: data)
    }
}

private enum MessageToBrowser: Codable {
    case message(data: Message)

    func toJson() throws -> String {
        guard let encoded = try String(bytes: JSONEncoder().encode(self), encoding: .utf8) else {
            throw "Encode failed"
        }
        return encoded
    }

    static func fromJson(data: String) throws -> MessageToBrowser {
        guard let data = data.data(using: .utf8) else {
            throw "Not a UTF-8 string"
        }
        return try JSONDecoder().decode(MessageToBrowser.self, from: data)
    }
}

private struct Chat {
    var prefix: String?
}

private class Subscriptions {
    var chat: Chat?
}

class BrowserEffectServer: NSObject {
    weak var webView: WKWebView?
    private let subscriptions = Subscriptions()

    func addScript(configuration: WKWebViewConfiguration) {
        configuration.userContentController.addUserScript(.init(
            source: moblinScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        configuration.userContentController.add(self, name: "moblin")
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

    private func send(message: MessageToBrowser) {
        do {
            let message = try message.toJson()
            let data = message.utf8Data.base64EncodedString()
            webView?.evaluateJavaScript("""
            moblin.handleMessage(window.atob("\(data)"))
            """)
        } catch {
            logger.info("browser-effect-server: Encode failed")
        }
    }

    private func handleMessage(message: String) throws {
        do {
            switch try MessageToMoblin.fromJson(data: message) {
            case let .subscribe(topic: topic):
                handleSubscribe(topic: topic)
            }
        } catch {
            logger.info("browser-effect-server: Decode failed with error: \(error)")
        }
    }

    private func handleSubscribe(topic: SubscribeTopic) {
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
