import SwiftUI
import WebKit

struct LeftOverlayView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.settings.database
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

    func messageColor() -> Color {
        if !model.isChatConfigured() {
            return .white
        } else if model.isChatConnected() && model.hasChatEmotes() {
            return .white
        } else {
            return .red
        }
    }

    func obsStatusColor() -> Color {
        if !model.isObsRemoteControlConfigured() {
            return .white
        } else if model.isObsConnected() {
            return .white
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if model.isShowingStatusStream() {
                StreamOverlayIconAndTextView(
                    icon: "dot.radiowaves.left.and.right",
                    text: model.statusStreamText()
                )
            }
            if model.isShowingStatusCamera() {
                StreamOverlayIconAndTextView(
                    icon: "camera",
                    text: model.statusCameraText()
                )
            }
            if model.isShowingStatusMic() {
                StreamOverlayIconAndTextView(
                    icon: "music.mic",
                    text: model.statusMicText()
                )
            }
            if model.isShowingStatusZoom() {
                StreamOverlayIconAndTextView(
                    icon: "magnifyingglass",
                    text: model.statusZoomText()
                )
            }
            if model.isShowingStatusObs() {
                StreamOverlayIconAndTextView(
                    icon: "xserve",
                    text: model.statusObsText(),
                    color: obsStatusColor()
                )
            }
            if model.isShowingStatusChat() {
                StreamOverlayIconAndTextView(
                    icon: "message",
                    text: model.statusChatText(),
                    color: messageColor()
                )
            }
            if model.isShowingStatusViewers() {
                StreamOverlayIconAndTextView(
                    icon: "eye",
                    text: model.statusViewersText(),
                    color: viewersColor()
                )
            }
            Spacer()
        }
    }
}
