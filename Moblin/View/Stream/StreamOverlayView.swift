import SwiftUI

private let startRadiusFraction = 0.45
private let endRadiusFraction = 0.5

struct ChatInfo: View {
    var message: String
    var icon: String?
    var iconColor: Color = .white

    var body: some View {
        VStack {
            Spacer()
            HStack {
                HStack {
                    if let icon {
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .bold()
                    }
                    Text(message)
                        .bold()
                        .foregroundColor(.white)
                }
                .padding([.top, .bottom], 5)
                .padding([.leading, .trailing], 10)
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
    let height: CGFloat
    let fullSize: Bool

    var body: some View {
        if model.isPortrait() {
            VStack {
                ZStack {
                    StreamOverlayChatView(model: model, chatSettings: chatSettings, chat: chat, fullSize: fullSize)
                    ChatPausedView(chat: chat)
                }
                if !fullSize {
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: 85)
                } else {
                    Divider()
                        .background(.gray)
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(height: controlBarWidthDefault)
                }
            }
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
                            .foregroundColor(.clear)
                            .frame(height: chatSettings.bottomPoints)
                    }
                }
                if fullSize {
                    Divider()
                        .background(.gray)
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: controlBarWidthDefault)
                }
            }
        }
    }
}

private struct FrontTorchView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if model.isPortrait() {
            VStack(spacing: 0) {
                Rectangle()
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        } else {
            HStack(spacing: 0) {
                Rectangle()
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
    let width: CGFloat
    let height: CGFloat

    private func leadingPadding() -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad || model.isPortrait() {
            return 15
        } else {
            return 0
        }
    }

    var body: some View {
        ZStack {
            if streamOverlay.isTorchOn && streamOverlay.isFrontCameraSelected {
                FrontTorchView()
            }
            ZStack {
                if model.showingPanel != .chat {
                    ChatOverlayView(
                        chatSettings: model.database.chat,
                        chat: model.chat,
                        height: height,
                        fullSize: false
                    )
                    .opacity(model.database.chat.enabled ? 1 : 0)
                    .allowsHitTesting(model.chat.interactiveChat)
                }
                HStack {
                    Spacer()
                    RightOverlayBottomView(show: model.database.show,
                                           streamOverlay: model.streamOverlay,
                                           zoom: model.zoom,
                                           width: width)
                }
                HStack {
                    LeftOverlayView(model: model, database: model.database)
                        .padding([.leading], leadingPadding())
                    Spacer()
                }
                HStack {
                    Spacer()
                    RightOverlayTopView(model: model, database: model.database)
                }
                HStack {
                    StreamOverlayDebugView(debugOverlay: model.debugOverlay)
                        .padding([.leading], leadingPadding())
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            .padding([.trailing, .top])
        }
    }
}
