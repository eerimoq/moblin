import SwiftUI

struct StreamOverlayView: View {
    @ObservedObject var model: Model

    func drawFocus(context: GraphicsContext, metrics: GeometryProxy,
                   focusPoint: CGPoint)
    {
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

    func messageText() -> String {
        if !model.isChatConfigured() {
            return "Not configured"
        } else if model.isChatConnected() {
            return String(format: "%.2f m/s", model.chatPostsPerSecond)
        } else {
            return ""
        }
    }

    func messageColor() -> Color {
        if !model.isChatConfigured() {
            return .white
        } else if model.isChatConnected() {
            return .white
        } else {
            return .red
        }
    }

    var body: some View {
        ZStack {
            if model.database.tapToFocus!, let focusPoint = model.manualFocusPoint {
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
            HStack {
                Spacer()
                RightOverlayView(model: model)
            }
            HStack {
                LeftOverlayView(model: model)
                    .allowsHitTesting(false)
                Spacer()
            }
            if model.database.show.chat {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Spacer()
                        StreamOverlayIconAndTextView(
                            icon: "message",
                            text: messageText(),
                            color: messageColor()
                        )
                        StreamOverlayChatView(
                            posts: model.chatPosts,
                            fontSize: model.database.chat!.fontSize
                        )
                    }
                    Spacer()
                }
            }
            HStack {
                StreamOverlayDebugView(model: model)
                Spacer()
            }
        }
        .padding([.trailing, .top])
    }
}
