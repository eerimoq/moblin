import SwiftUI
import WebKit

private struct CollapsedViewersView: View {
    @ObservedObject var status: StatusTopLeft
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "eye")
                .frame(width: 17, height: 17)
                .padding([.leading], 2)
                .foregroundStyle(color)
            if !status.numberOfViewers.isEmpty {
                Text(status.numberOfViewers)
                    .foregroundStyle(.white)
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

private struct StreamStatusView: View {
    @ObservedObject var status: StatusTopLeft
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "dot.radiowaves.left.and.right",
            text: status.streamText,
            textPlacement: textPlacement
        )
    }
}

private struct ZoomView: View {
    @ObservedObject var zoom: Zoom
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "magnifyingglass",
            text: zoom.statusText(),
            textPlacement: textPlacement
        )
    }
}

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopLeft
    @ObservedObject var mic: Mic
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
        if model.isShowingStatusStream() {
            StreamStatusView(status: status, textPlacement: textPlacement)
        }
        if model.isShowingStatusCamera() {
            StreamOverlayIconAndTextView(
                icon: "camera",
                text: status.statusCameraText,
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusMic() {
            StreamOverlayIconAndTextView(
                icon: "music.mic",
                text: mic.current.name,
                textPlacement: textPlacement
            )
        }
        if textPlacement != .hide, model.isShowingStatusZoom() {
            ZoomView(zoom: model.zoom, textPlacement: textPlacement)
        }
        if model.isShowingStatusObs() {
            StreamOverlayIconAndTextView(
                icon: "xserve",
                text: status.statusObsText,
                textPlacement: textPlacement,
                color: obsStatusColor()
            )
        }
        if model.isShowingStatusEvents() {
            StreamOverlayIconAndTextView(
                icon: "megaphone",
                text: status.statusEventsText,
                textPlacement: textPlacement,
                color: eventsColor()
            )
        }
        if model.isShowingStatusChat() {
            StreamOverlayIconAndTextView(
                icon: "message",
                text: status.statusChatText,
                textPlacement: textPlacement,
                color: chatColor()
            )
        }
        if model.isShowingStatusViewers() {
            if textPlacement == .hide {
                CollapsedViewersView(status: status, color: .white)
            } else {
                StreamOverlayIconAndTextView(
                    icon: "eye",
                    text: model.statusViewersText(),
                    textPlacement: textPlacement
                )
            }
        }
    }
}

struct LeftOverlayView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            VStack(alignment: .leading, spacing: 1) {
                if database.verboseStatuses {
                    StatusesView(show: database.show,
                                 status: model.statusTopLeft,
                                 mic: model.mic,
                                 textPlacement: .afterIcon)
                } else {
                    HStack(spacing: 1) {
                        StatusesView(show: database.show,
                                     status: model.statusTopLeft,
                                     mic: model.mic,
                                     textPlacement: .hide)
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
