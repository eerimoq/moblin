import SwiftUI
import WebKit

struct LeftOverlayView: View {
    @EnvironmentObject var model: Model

    func viewersColor() -> Color {
        if model.isTwitchViewersConfigured() && !model.isTwitchPubSubConnected() {
            return .red
        }
        return .white
    }

    func eventsColor() -> Color {
        if !model.isEventsConfigured() {
            return .white
        } else if model.isEventsConnected() {
            return .white
        } else {
            return .red
        }
    }

    func chatColor() -> Color {
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
                text: model.currentMic.name
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
                show: model.isShowingStatusEvents(),
                icon: "megaphone",
                text: model.statusEventsText(),
                color: eventsColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusChat(),
                icon: "message",
                text: model.statusChatText(),
                color: chatColor()
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
