import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context _: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let wkwebView = WKWebView(frame: .zero, configuration: configuration)
        let request = URLRequest(url: url)
        wkwebView.load(request)
        return wkwebView
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

struct LeftOverlayView: View {
    @ObservedObject var model: Model

    var database: Database {
        model.settings.database
    }

    var stream: SettingsStream {
        model.stream
    }

    func streamText() -> String {
        var proto: String
        if stream.getProtocol() == .srt && stream.isSrtla() {
            proto = "SRTLA"
        } else if stream.getProtocol() == .rtmp && stream.isRtmps() {
            proto = "RTMPS"
        } else {
            proto = stream.getProtocol().rawValue
        }
        let bitrate = formatBytesPerSecond(speed: Int64(stream.bitrate))
        let resolution = stream.resolution.rawValue
        let codec = stream.codec.rawValue
        return "\(stream.name) (\(resolution), \(stream.fps), \(codec), \(proto), \(bitrate))"
    }

    func messageText() -> String {
        if model.isChatConnected() {
            return String(format: "%.2f m/s", model.chatPostsPerSecond)
        } else {
            return ""
        }
    }

    func messageColor() -> Color {
        if model.isChatConnected() {
            return .white
        } else {
            return .red
        }
    }

    func viewersText() -> String {
        if model.isTwitchPubSubConnected() {
            return model.numberOfViewers
        } else {
            return ""
        }
    }

    func viewersColor() -> Color {
        if model.isTwitchPubSubConnected() {
            return .white
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if database.show.stream {
                StreamOverlayIconAndTextView(
                    icon: "dot.radiowaves.left.and.right",
                    text: streamText()
                )
            }
            if database.show.viewers {
                StreamOverlayIconAndTextView(
                    icon: "eye",
                    text: viewersText(),
                    color: viewersColor()
                )
            }
            // WebView(url: URL(string: "https://www.youtube.com/watch?v=XAaw_cxNY5w&t=4347s")!)
            Spacer()
            if database.show.chat {
                StreamOverlayIconAndTextView(
                    icon: "message",
                    text: messageText(),
                    color: messageColor()
                )
                StreamOverlayChatView(posts: model.chatPosts)
            }
        }
    }
}
