import SwiftUI

struct ChatInfo: View {
    var message: String
    var icon: String? = nil
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

    func drawFocus(context: GraphicsContext, metrics: GeometryProxy, focusPoint: CGPoint) {
        let sideLength = 70.0
        let x = metrics.size.width * focusPoint.x - sideLength / 2
        let y = metrics.size.height * focusPoint.y - sideLength / 2
        let origin = CGPoint(x: x, y: y)
        let size = CGSize(width: sideLength, height: sideLength)
        context.stroke(
            Path(roundedRect: CGRect(origin: origin, size: size), cornerRadius: 2.0),
            with: .color(.yellow),
            lineWidth: 1
        )
    }

    var body: some View {
        ZStack {
            if model.database.tapToFocus, let focusPoint = model.manualFocusPoint {
                GeometryReader { metrics in
                    Canvas { context, _ in
                        drawFocus(
                            context: context,
                            metrics: metrics,
                            focusPoint: focusPoint
                        )
                    }
                    .allowsHitTesting(false)
                }
            }
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
            .allowsHitTesting(model.interactiveChat)
            HStack {
                Spacer()
                RightOverlayView()
            }
            HStack {
                LeftOverlayView()
                Spacer()
            }
            .allowsHitTesting(false)
            HStack {
                StreamOverlayDebugView()
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .padding([.trailing, .top])
    }
}
