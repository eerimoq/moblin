import SwiftUI
import WebKit

private struct CollapsedViewersView: View {
    @EnvironmentObject var model: Model
    var color: Color

    var body: some View {
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

private struct StatusesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var show: SettingsShow
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
            StreamOverlayIconAndTextView(
                icon: "dot.radiowaves.left.and.right",
                text: model.statusStreamText(),
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusCamera() {
            StreamOverlayIconAndTextView(
                icon: "camera",
                text: model.statusCameraText(),
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusMic() {
            StreamOverlayIconAndTextView(
                icon: "music.mic",
                text: model.currentMic.name,
                textPlacement: textPlacement
            )
        }
        if textPlacement != .hide, model.isShowingStatusZoom() {
            StreamOverlayIconAndTextView(
                icon: "magnifyingglass",
                text: model.statusZoomText(),
                textPlacement: textPlacement
            )
        }
        if model.isShowingStatusObs() {
            StreamOverlayIconAndTextView(
                icon: "xserve",
                text: model.statusObsText(),
                textPlacement: textPlacement,
                color: obsStatusColor()
            )
        }
        if model.isShowingStatusEvents() {
            StreamOverlayIconAndTextView(
                icon: "megaphone",
                text: model.statusEventsText,
                textPlacement: textPlacement,
                color: eventsColor()
            )
        }
        if model.isShowingStatusChat() {
            StreamOverlayIconAndTextView(
                icon: "message",
                text: model.statusChatText,
                textPlacement: textPlacement,
                color: chatColor()
            )
        }
        if model.isShowingStatusViewers() {
            if textPlacement == .hide {
                CollapsedViewersView(color: .white)
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
    var model: Model
    @ObservedObject var database: Database

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            VStack(alignment: .leading, spacing: 1) {
                if database.verboseStatuses {
                    StatusesView(show: database.show, textPlacement: .afterIcon)
                } else {
                    HStack(spacing: 1) {
                        StatusesView(show: database.show, textPlacement: .hide)
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
