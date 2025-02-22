import SwiftUI
import WebKit

private struct CollapsedViewersView: View {
    @EnvironmentObject var model: Model
    var show: Bool
    var color: Color

    var body: some View {
        if show {
            HStack(spacing: 1) {
                Image(systemName: "eye")
                    .frame(width: 17, height: 17)
                    .padding([.leading], 2)
                    .foregroundColor(color)
                if !model.numberOfViewers.isEmpty {
                    Text(model.numberOfViewers)
                        .foregroundColor(.white)
                        .padding([.leading, .trailing], 2)
                }
            }
            .font(smallFont)
            .background(backgroundColor)
            .cornerRadius(5)
            .padding(20)
            .contentShape(Rectangle())
            .padding(-20)
        }
    }
}

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    let textPlacement: StreamOverlayIconAndTextPlacement

    func eventsColor() -> Color {
        if !model.isEventsConfigured() {
            return .white
        } else if model.isEventsRemoteControl() {
            if model.isRemoteControlStreamerConnected() {
                return .white
            } else {
                return .red
            }
        } else {
            if model.isEventsConnected() {
                return .white
            } else {
                return .red
            }
        }
    }

    func chatColor() -> Color {
        if !model.isChatConfigured() {
            return .white
        } else if model.isChatRemoteControl() {
            if model.isRemoteControlStreamerConnected() {
                return .white
            } else {
                return .red
            }
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
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusStream(),
            icon: "dot.radiowaves.left.and.right",
            text: model.statusStreamText(),
            textPlacement: textPlacement
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusCamera(),
            icon: "camera",
            text: model.statusCameraText(),
            textPlacement: textPlacement
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusMic(),
            icon: "music.mic",
            text: model.currentMic.name,
            textPlacement: textPlacement
        )
        if textPlacement != .hide {
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusZoom(),
                icon: "magnifyingglass",
                text: model.statusZoomText(),
                textPlacement: textPlacement
            )
        }
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusObs(),
            icon: "xserve",
            text: model.statusObsText(),
            textPlacement: textPlacement,
            color: obsStatusColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusEvents(),
            icon: "megaphone",
            text: model.statusEventsText(),
            textPlacement: textPlacement,
            color: eventsColor()
        )
        StreamOverlayIconAndTextView(
            show: model.isShowingStatusChat(),
            icon: "message",
            text: model.statusChatText(),
            textPlacement: textPlacement,
            color: chatColor()
        )
        if textPlacement == .hide {
            CollapsedViewersView(show: model.isShowingStatusViewers(), color: .white)
        } else {
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusViewers(),
                icon: "eye",
                text: model.statusViewersText(),
                textPlacement: textPlacement,
                color: .white
            )
        }
    }
}

struct LeftOverlayView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            VStack(alignment: .leading, spacing: 1) {
                if model.verboseStatuses {
                    StatusesView(textPlacement: .afterIcon)
                } else {
                    HStack(spacing: 1) {
                        StatusesView(textPlacement: .hide)
                    }
                }
            }
            .onTapGesture {
                model.toggleVerboseStatuses()
            }
            Spacer()
        }
    }
}
