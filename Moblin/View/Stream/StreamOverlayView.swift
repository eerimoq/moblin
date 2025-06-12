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

private struct ChatOverlayView: View {
    @EnvironmentObject var model: Model
    let height: CGFloat

    var body: some View {
        if model.isPortrait() {
            VStack {
                ZStack {
                    StreamOverlayChatView(chat: model.chat)
                    ChatPausedView(chat: model.chat)
                }
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: 85)
            }
        } else {
            VStack {
                ZStack {
                    GeometryReader { metrics in
                        StreamOverlayChatView(chat: model.chat)
                            .frame(width: metrics.size.width * 0.95)
                    }
                    ChatPausedView(chat: model.chat)
                }
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: model.database.chat.bottomPoints)
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
            if model.isTorchOn && model.isFrontCameraSelected {
                FrontTorchView()
            }
            ZStack {
                if model.showingPanel != .chat {
                    ChatOverlayView(height: height)
                        .opacity(model.database.chat.enabled ? 1 : 0)
                        .allowsHitTesting(model.interactiveChat)
                }
                HStack {
                    Spacer()
                    RightOverlayBottomView(show: model.database.show, width: width)
                }
                HStack {
                    LeftOverlayView()
                        .padding([.leading], leadingPadding())
                    Spacer()
                }
                HStack {
                    Spacer()
                    RightOverlayTopView()
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
