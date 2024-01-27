import SwiftUI
import WebKit

struct LeftOverlayView: View {
    @EnvironmentObject var model: Model

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
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusStream(),
                icon: "dot.radiowaves.left.and.right",
                text: model.statusStreamText()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusCamera(),
                icon: "camera",
                text: model.statusCameraText()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusMic(),
                icon: "music.mic",
                text: model.mic.name
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusZoom(),
                icon: "magnifyingglass",
                text: model.statusZoomText()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusObs(),
                icon: "xserve",
                text: model.statusObsText(),
                color: obsStatusColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusChat(),
                icon: "message",
                text: model.statusChatText(),
                color: messageColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusViewers(),
                icon: "eye",
                text: model.statusViewersText(),
                color: viewersColor()
            )
            Spacer()
        }
    }
}
