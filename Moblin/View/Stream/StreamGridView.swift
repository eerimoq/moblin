import SwiftUI

struct StreamGridView: View {
    func draw(context: GraphicsContext, size: CGSize) {
        let height = size.height / 3
        let width = size.width / 3
        var path = Path()
        path.move(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: size.height))
        path.move(to: CGPoint(x: 2 * width, y: 0))
        path.addLine(to: CGPoint(x: 2 * width, y: size.height))
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: size.width, y: height))
        path.move(to: CGPoint(x: 0, y: 2 * height))
        path.addLine(to: CGPoint(x: size.width, y: 2 * height))
        context.stroke(path, with: .color(.gray), lineWidth: 1.5)
    }

    var body: some View {
        GeometryReader { metrics in
            Canvas { context, _ in
                draw(context: context, size: metrics.size)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}
