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

private struct ChatOverlayView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if model.stream.portrait! || model.stream.portraitUI! {
            VStack {
                ZStack {
                    StreamOverlayChatView()
                        .opacity(model.showChatMessages ? 1 : 0)
                    if !model.showChatMessages {
                        ChatInfo(
                            message: String(localized: "Chat is hidden"),
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .yellow
                        )
                    } else if model.chatPaused {
                        ChatInfo(
                            message: String(
                                localized: "Chat paused: \(model.pausedChatPostsCount) new messages"
                            )
                        )
                    }
                }
                .opacity(model.database.chat.enabled! ? 1 : 0)
                .allowsHitTesting(model.interactiveChat && model.showChatMessages)
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: 85)
            }
        } else {
            ZStack {
                GeometryReader { metrics in
                    StreamOverlayChatView()
                        .frame(width: metrics.size.width * 0.95)
                }
                .opacity(model.showChatMessages ? 1 : 0)
                if !model.showChatMessages {
                    ChatInfo(
                        message: String(localized: "Chat is hidden"),
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .yellow
                    )
                } else if model.chatPaused {
                    ChatInfo(
                        message: String(
                            localized: "Chat paused: \(model.pausedChatPostsCount) new messages"
                        )
                    )
                }
            }
            .opacity(model.database.chat.enabled! ? 1 : 0)
            .allowsHitTesting(model.interactiveChat && model.showChatMessages)
        }
    }
}

private struct FrontTorchView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if model.stream.portrait! {
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

    private func leadingPadding() -> CGFloat {
        if UIDevice.current
            .userInterfaceIdiom == .pad || (model.stream.portrait! || model.stream.portraitUI!)
        {
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
                ChatOverlayView()
                HStack {
                    LeftOverlayView()
                        .padding([.leading], leadingPadding())
                    Spacer()
                }
                .allowsHitTesting(false)
                HStack {
                    Spacer()
                    RightOverlayView(width: width)
                }
                HStack {
                    StreamOverlayDebugView()
                        .padding([.leading], leadingPadding())
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            .padding([.trailing, .top])
        }
    }
}
