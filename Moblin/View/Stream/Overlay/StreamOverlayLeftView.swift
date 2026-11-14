import SwiftUI
import WebKit

private struct CollapsedViewersView: View {
    let iconColor: Color
    let numberOfViewersCompact: String

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "eye")
                .frame(width: 17, height: 17)
                .padding(.leading, 2)
                .foregroundStyle(iconColor)
            Text(numberOfViewersCompact)
                .foregroundStyle(.white)
                .padding(.horizontal, 2)
        }
        .font(smallFont)
        .background(backgroundColor)
        .cornerRadius(5)
        .padding(20)
        .contentShape(Rectangle())
        .padding(-20)
    }
}

private struct ViewersLogoView: View {
    let platform: Platform

    var body: some View {
        Image(platform.imageName())
            .resizable()
            .scaledToFit()
            .padding(.vertical, 2)
            .frame(height: 18)
    }
}

private struct ViewersView: View {
    let iconColor: Color
    let streamingPlatformStatuses: [StreamingPlatformStatus]

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "eye")
                .frame(width: 17, height: 17)
                .padding(.horizontal, 2)
                .foregroundStyle(iconColor)
                .background(backgroundColor)
                .cornerRadius(5)
            HStack(spacing: 2) {
                ForEach(streamingPlatformStatuses, id: \.platform) {
                    ViewersLogoView(platform: $0.platform)
                    switch $0.status {
                    case let .live(viewerCount: viewerCount):
                        Text(countFormatter.format(viewerCount))
                            .foregroundStyle(.white)
                    case .unknown:
                        Text("Unknown")
                            .foregroundStyle(.orange)
                    case .offline:
                        Text("Offline")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 2)
            .background(backgroundColor)
            .cornerRadius(5)
        }
        .font(smallFont)
        .padding(20)
        .contentShape(Rectangle())
        .padding(-20)
    }
}

private struct ChatStatusView: View {
    let chatPlatformStatuses: [ChatPlatformStatus]
    let statusChatText: String
    let foregroundColor: Color

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "message")
                .frame(width: 17, height: 17)
                .padding(.horizontal, 2)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .cornerRadius(5)
            HStack(spacing: 2) {
                if chatPlatformStatuses.isEmpty {
                    Text(statusChatText)
                        .foregroundStyle(.white)
                } else {
                    ForEach(chatPlatformStatuses, id: \.platform) {
                        ViewersLogoView(platform: $0.platform)
                        if $0.connected {
                            Text("Connected")
                                .foregroundStyle(.white)
                        } else {
                            Text("Disconnected")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
            .background(backgroundColor)
            .cornerRadius(5)
        }
        .font(smallFont)
        .padding(20)
        .contentShape(Rectangle())
        .padding(-20)
    }
}

private struct StreamStatusView: View {
    let streamText: String
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "dot.radiowaves.left.and.right",
            text: streamText,
            textPlacement: textPlacement
        )
    }
}

private struct ZoomView: View {
    @ObservedObject var level: ZoomLevel
    let textPlacement: StreamOverlayIconAndTextPlacement

    var body: some View {
        StreamOverlayIconAndTextView(
            icon: "magnifyingglass",
            text: level.statusText(),
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
            .white
        } else if model.isRemoteControlChatAndEvents(platform: nil) {
            if model.isRemoteControlStreamerConnected() {
                .white
            } else {
                .red
            }
        } else if model.isEventsConnected() {
            .white
        } else {
            .red
        }
    }

    func chatColor() -> Color {
        if !model.isChatConfigured() {
            .white
        } else if model.isRemoteControlChatAndEvents(platform: nil) {
            if model.isRemoteControlStreamerConnected() {
                .white
            } else {
                .red
            }
        } else if model.isChatConnected(), model.hasChatEmotes() {
            .white
        } else {
            .red
        }
    }

    func obsStatusColor() -> Color {
        if !model.isObsRemoteControlConfigured() {
            .white
        } else if model.isObsConnected() {
            .white
        } else {
            .red
        }
    }

    var body: some View {
        if model.isShowingStatusStream() {
            StreamStatusView(streamText: status.streamText, textPlacement: textPlacement)
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
            ZoomView(level: model.zoom.level, textPlacement: textPlacement)
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
            if textPlacement == .hide {
                StreamOverlayIconAndTextView(
                    icon: "message",
                    text: status.statusChatText,
                    textPlacement: textPlacement,
                    color: chatColor()
                )
            } else {
                ChatStatusView(
                    chatPlatformStatuses: status.chatPlatformStatuses,
                    statusChatText: status.statusChatText,
                    foregroundColor: chatColor()
                )
            }
        }
        if model.isShowingStatusViewers() {
            if textPlacement == .hide {
                CollapsedViewersView(
                    iconColor: status.numberOfViewersIconColor,
                    numberOfViewersCompact: status.numberOfViewersCompact
                )
            } else {
                ViewersView(
                    iconColor: status.numberOfViewersIconColor,
                    streamingPlatformStatuses: status.streamingPlatformStatuses
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
