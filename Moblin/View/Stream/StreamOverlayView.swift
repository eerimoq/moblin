import SwiftUI

private let startRadiusFraction = 0.45
private let endRadiusFraction = 0.5

private struct BitrateTimelineView: View {
    @ObservedObject var show: SettingsShow
    @ObservedObject var connectionTimeline: ConnectionTimeline

    private let segmentSize: CGFloat = 10
    private let segmentSpacing: CGFloat = 2

    var body: some View {
        if show.connectionTimeline {
            GeometryReader { proxy in
                let segmentHeight = segmentSize + segmentSpacing
                let visibleCount = max(Int(ceil(proxy.size.height / segmentHeight)) + 1, 1)
                let samples = connectionTimeline.samples.suffix(visibleCount)
                let topPadding = max(proxy.size.height - CGFloat(samples.count) * segmentHeight, 0)

                VStack(spacing: segmentSpacing) {
                    Spacer(minLength: topPadding)
                    ForEach(Array(samples.enumerated()), id: \.offset) { _, isBad in
                        Rectangle()
                            .fill(isBad ? Color.red.opacity(0.85) : Color.clear)
                            .frame(width: segmentSize, height: segmentSize)
                    }
                }
                .frame(width: segmentSize, height: proxy.size.height, alignment: .bottom)
            }
            .frame(width: segmentSize)
            .allowsHitTesting(false)
        }
    }
}

struct ChatInfo: View {
    let message: String

    var body: some View {
        VStack {
            Spacer()
            HStack {
                HStack {
                    Text(message)
                        .bold()
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(.black.opacity(0.8))
                .cornerRadius(10)
                Spacer()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ChatPausedView: View {
    @ObservedObject var chat: ChatProvider

    var body: some View {
        if chat.paused {
            ChatInfo(
                message: String(localized: "Chat paused: \(chat.pausedPostsCount) new messages")
            )
            .padding(2)
        }
    }
}

struct ChatOverlayView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var chat: ChatProvider
    @ObservedObject var orientation: Orientation
    @ObservedObject var quickButtons: SettingsQuickButtons
    let fullSize: Bool

    var body: some View {
        if orientation.isPortrait {
            VStack {
                ZStack {
                    StreamOverlayChatView(
                        model: model,
                        chatSettings: chatSettings,
                        chat: chat,
                        fullSize: fullSize
                    )
                    ChatPausedView(chat: chat)
                }
                if !fullSize {
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(height: 85)
                } else {
                    Divider()
                        .background(.gray)
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(height: controlBarWidthDefault)
                }
            }
            .allowsHitTesting(chat.interactiveChat)
        } else {
            HStack(spacing: 0) {
                VStack {
                    ZStack {
                        HStack(spacing: 0) {
                            GeometryReader { metrics in
                                StreamOverlayChatView(
                                    model: model,
                                    chatSettings: chatSettings,
                                    chat: chat,
                                    fullSize: fullSize
                                )
                                .frame(width: metrics.size.width * 0.95)
                            }
                        }
                        ChatPausedView(chat: chat)
                    }
                    if !fullSize {
                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(height: chatSettings.bottomPoints)
                    }
                }
                if fullSize {
                    Divider()
                        .background(.gray)
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(width: controlBarWidth(quickButtons: quickButtons))
                }
            }
            .allowsHitTesting(chat.interactiveChat)
        }
    }
}

private struct FrontTorchView: View {
    @ObservedObject var orientation: Orientation

    var body: some View {
        if orientation.isPortrait {
            VStack(spacing: 0) {
                Rectangle()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle()
                    .fill(
                        EllipticalGradient(
                            gradient: .init(colors: [.clear, .white]),
                            startRadiusFraction: startRadiusFraction,
                            endRadiusFraction: endRadiusFraction
                        )
                    )
                    .aspectRatio(1, contentMode: .fill)
                Rectangle()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        } else {
            HStack(spacing: 0) {
                Rectangle()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle()
                    .fill(
                        EllipticalGradient(
                            gradient: .init(colors: [.clear, .white]),
                            startRadiusFraction: startRadiusFraction,
                            endRadiusFraction: endRadiusFraction
                        )
                    )
                    .aspectRatio(1, contentMode: .fill)
                Rectangle()
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
    }
}

struct StreamOverlayView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var streamOverlay: StreamOverlay
    @ObservedObject var chatSettings: SettingsChat
    @ObservedObject var orientation: Orientation
    let width: CGFloat

    private let timelineWidth: CGFloat = 10

    private func leadingPadding() -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad || orientation.isPortrait {
            15
        } else {
            0
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                BitrateTimelineView(show: model.database.show, connectionTimeline: model.bitrateTimeline)
                    .frame(width: timelineWidth)
                    .padding(.leading, leadingPadding())
                    .padding(.top)
                Spacer()
            }
            .allowsHitTesting(false)
            if streamOverlay.isTorchOn, streamOverlay.isFrontCameraSelected {
                FrontTorchView(orientation: orientation)
            }
            ZStack {
                if model.showingPanel != .chat {
                    ChatOverlayView(chatSettings: chatSettings,
                                    chat: model.chat,
                                    orientation: orientation,
                                    quickButtons: model.database.quickButtonsGeneral,
                                    fullSize: false)
                        .opacity(chatSettings.enabled ? 1 : 0)
                }
                HStack {
                    Spacer()
                    RightOverlayBottomView(database: model.database,
                                           show: model.database.show,
                                           streamOverlay: model.streamOverlay,
                                           zoom: model.zoom,
                                           width: width)
                }
                HStack {
                    LeftOverlayView(model: model, database: model.database)
                        .padding(.leading, leadingPadding())
                    Spacer()
                }
                HStack {
                    Spacer()
                    RightOverlayTopView(model: model, database: model.database)
                }
                HStack {
                    StreamOverlayDebugView(debugOverlay: model.debugOverlay)
                        .padding(.leading, leadingPadding())
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            .padding([.trailing, .top])
        }
    }
}
