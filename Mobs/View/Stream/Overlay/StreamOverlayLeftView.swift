import SwiftUI

struct LeftOverlayView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.settings.database
        }
    }

    func streamText() -> String {
        guard let stream = model.stream else {
            return ""
        }
        var proto = stream.proto
        if proto == "SRT" && stream.srtla {
            proto = "SRTLA"
        }
        return "\(stream.name) (\(stream.resolution), \(stream.fps), \(proto))"
    }
    
    func messageText() -> String {
        if model.isTwitchChatConnected() {
            return String(format: "%.2f m/s", model.twitchChatPostsPerSecond)
        } else {
            return ""
        }
    }
    
    func viewersText() -> String {
        if model.isTwitchPubSubConnected() {
            return model.numberOfViewers
        } else {
            return ""
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if database.show.stream {
                StreamOverlayIconAndTextView(icon: "dot.radiowaves.left.and.right", text: streamText())
            }
            if database.show.viewers {
                StreamOverlayIconAndTextView(icon: "eye", text: viewersText())
            }
            if database.show.uptime {
                StreamOverlayIconAndTextView(icon: "deskclock", text: model.uptime)
            }
            Spacer()
            if database.show.chat {
                StreamOverlayIconAndTextView(icon: "message", text: messageText())
                StreamOverlayChatView(posts: model.twitchChatPosts)
            }
        }
    }
}
