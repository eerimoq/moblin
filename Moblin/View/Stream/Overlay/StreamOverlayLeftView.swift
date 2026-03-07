import SwiftUI
import WebKit

private struct CollapsedViewersView: View {
    @ObservedObject var status: StatusTopLeft

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "eye")
                .frame(width: 17, height: 17)
                .padding([.leading], 2)
                .foregroundStyle(status.numberOfViewersIconColor)
            Text(status.numberOfViewersCompact)
                .foregroundStyle(.white)
                .padding([.leading, .trailing], 2)
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
            .aspectRatio(contentMode: .fit)
            .padding([.top, .bottom], 2)
            .frame(height: 18)
    }
}

private struct ViewersView: View {
    @ObservedObject var status: StatusTopLeft

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "eye")
                .frame(width: 17, height: 17)
                .padding([.leading, .trailing], 2)
                .foregroundStyle(status.numberOfViewersIconColor)
                .background(backgroundColor)
                .cornerRadius(5)
            HStack(spacing: 2) {
                ForEach(status.streamingPlatformStatuses, id: \.platform) {
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
            .padding([.leading, .trailing], 2)
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
    @ObservedObject var status: StatusTopLeft
    let foregroundColor: Color

    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "message")
                .frame(width: 17, height: 17)
                .padding([.leading, .trailing], 2)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .cornerRadius(5)
            HStack(spacing: 2) {
                if status.chatPlatformStatuses.isEmpty {
                    Text(status.statusChatText)
                } else {
                    ForEach(status.chatPlatformStatuses, id: \.platform) {
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
            .padding([.leading, .trailing], 2)
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
    // periphery:ignore
    @ObservedObject var show: SettingsShow
    @ObservedObject var status: StatusTopLeft
    @ObservedObject var mic: Mic
    let textPlacement: StreamOverlayIconAndTextPlacement

    func eventsColor() -> Color {
        if !model.isEventsConfigured() {
            return .white
        } else if model.isRemoteControlChatAndEvents(platform: nil) {
            if model.isRemoteControlStreamerConnected() {
                return .white
            } else {
                return .red
            }
        } else if model.isEventsConnected() {
            return .white
        } else {
            return .red
        }
    }

    func chatColor() -> Color {
        if !model.isChatConfigured() {
            return .white
        } else if model.isRemoteControlChatAndEvents(platform: nil) {
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

    func selectedMicNames() -> String {
        let names = model.database.mics.mics
            .filter { mic.isSelected(mic: $0) }
            .map(\.name)
        if names.isEmpty {
            return mic.current.name
        }
        return names.joined(separator: ", ")
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
                text: selectedMicNames(),
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
            if textPlacement == .hide {
                StreamOverlayIconAndTextView(
                    icon: "message",
                    text: status.statusChatText,
                    textPlacement: textPlacement,
                    color: chatColor()
                )
            } else {
                ChatStatusView(status: status, foregroundColor: chatColor())
            }
        }
        if model.isShowingStatusViewers() {
            if textPlacement == .hide {
                CollapsedViewersView(status: status)
            } else {
                ViewersView(status: status)
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
