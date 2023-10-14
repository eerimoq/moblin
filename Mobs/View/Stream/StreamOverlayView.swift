import SwiftUI

struct StreamOverlayView: View {
    @ObservedObject var model: Model

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
            HStack {
                Spacer()
                RightOverlayView(model: model)
            }
            GeometryReader { metrics in
                HStack {
                    LeftOverlayView(model: model)
                        .allowsHitTesting(false)
                    Spacer()
                }
                .frame(width: metrics.size.width * 0.7)
                if model.database.tapToFocus!, let focusPoint = model.manualFocusPoint {
                    Canvas { context, _ in
                        drawFocus(context: context, metrics: metrics, focusPoint: focusPoint)
                    }
                    .allowsHitTesting(false)
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
