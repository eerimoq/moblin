import SwiftUI
import WebKit

struct LeftOverlayView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.settings.database
    }

    var stream: SettingsStream {
        model.stream
    }

    func streamText() -> String {
        let proto = stream.protocolString()
        let resolution = stream.resolutionString()
        let codec = stream.codecString()
        let bitrate = stream.bitrateString()
        let audioCodec = stream.audioCodecString()
        let audioBitrate = stream.audioBitrateString()
        return """
        \(stream.name) (\(resolution), \(stream.fps), \(proto), \(codec) \(bitrate), \
        \(audioCodec) \(audioBitrate))
        """
    }

    func viewersText() -> String {
        if !model.isViewersConfigured() {
            return String(localized: "Not configured")
        } else if model.isTwitchPubSubConnected() {
            return model.numberOfViewers
        } else {
            return ""
        }
    }

    func viewersColor() -> Color {
        if model.stream.twitchChannelId == "" {
            return .white
        } else if model.isTwitchPubSubConnected() {
            return .white
        } else {
            return .red
        }
    }

    func messageText() -> String {
        if !model.isChatConfigured() {
            return String(localized: "Not configured")
        } else if model.isChatConnected() {
            return String(
                format: String(localized: "%@ (%@ total)"),
                model.chatPostsRate,
                countFormatter.format(model.chatPostsTotal)
            )
        } else {
            return ""
        }
    }

    func messageColor() -> Color {
        if !model.isChatConfigured() {
            return .white
        } else if model.isChatConnected() && model.hasChatEmotes() {
            return .white
        } else {
            return .red
        }
    }

    func obsStatusText() -> String {
        if !model.isObsConfigured() {
            return String(localized: "Not configured")
        } else if model.isObsConnected() {
            if model.obsStreaming && model.obsRecording {
                return "\(model.obsCurrentSceneStatus) (Streaming, Recording)"
            } else if model.obsStreaming {
                return "\(model.obsCurrentSceneStatus) (Streaming)"
            } else if model.obsRecording {
                return "\(model.obsCurrentSceneStatus) (Recording)"
            } else {
                return model.obsCurrentSceneStatus
            }
        } else {
            return model.obsConnectionErrorMessage()
        }
    }

    func obsStatusColor() -> Color {
        if !model.isObsConfigured() {
            return .white
        } else if model.isObsConnected() {
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
            if database.show.cameras! {
                StreamOverlayIconAndTextView(
                    icon: "camera",
                    text: cameraName(device: model.cameraDevice)
                )
            }
            if database.show.microphone {
                StreamOverlayIconAndTextView(
                    icon: "music.mic",
                    text: model.mic.name
                )
            }
            if database.show.zoom {
                StreamOverlayIconAndTextView(
                    icon: "magnifyingglass",
                    text: String(format: "%.1f", model.zoomX)
                )
            }
            if model.database.show.obsStatus! {
                StreamOverlayIconAndTextView(
                    icon: "photo",
                    text: obsStatusText(),
                    color: obsStatusColor()
                )
            }
            if model.database.show.chat {
                StreamOverlayIconAndTextView(
                    icon: "message",
                    text: messageText(),
                    color: messageColor()
                )
            }
            if database.show.viewers {
                StreamOverlayIconAndTextView(
                    icon: "eye",
                    text: viewersText(),
                    color: viewersColor()
                )
            }
            Spacer()
        }
    }
}
