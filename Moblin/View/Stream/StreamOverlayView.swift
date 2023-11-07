import SwiftUI

struct StreamOverlayView: View {
    @EnvironmentObject var model: Model

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
            HStack {
                Spacer()
                RightOverlayView()
            }
            HStack {
                LeftOverlayView()
                Spacer()
            }
            .allowsHitTesting(false)
            if model.database.show.chat && model.showChatMessages {
                ZStack {
                    GeometryReader { metrics in
                        StreamOverlayChatView()
                            .frame(width: metrics.size.width * 0.95)
                            .allowsHitTesting(model.chatPaused)
                    }
                    if model.chatPaused {
                        VStack {
                            Spacer()
                            HStack {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    Text("Chat is paused")
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
                    }
                }
            }
            HStack {
                StreamOverlayDebugView()
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .padding([.trailing, .top])
    }
}
