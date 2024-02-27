import SwiftUI

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

struct StreamOverlayView: View {
    @EnvironmentObject var model: Model

    private func leadingPadding() -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 15
        } else {
            return 0
        }
    }

    var body: some View {
        ZStack {
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
                        message: String(localized: "Chat paused: \(model.pausedChatPostsCount) new messages")
                    )
                }
            }
            .opacity(model.database.chat.enabled! ? 1 : 0)
            .allowsHitTesting(model.interactiveChat)
            HStack {
                Spacer()
                RightOverlayView()
            }
            HStack {
                LeftOverlayView()
                    .padding([.leading], leadingPadding())
                Spacer()
            }
            .allowsHitTesting(false)
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
