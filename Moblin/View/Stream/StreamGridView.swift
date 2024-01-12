import SwiftUI

struct StreamGridView: View {
    var body: some View {
        Canvas { context, size in
            let height = size.height / 3
            let width = size.width / 3
            var path = Path()
            // Horizontal
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: size.width, y: height))
            path.move(to: CGPoint(x: 0, y: 2 * height))
            path.addLine(to: CGPoint(x: size.width, y: 2 * height))
            // Vertical
            path.move(to: CGPoint(x: width, y: 0))
            path.addLine(to: CGPoint(x: width, y: size.height))
            path.move(to: CGPoint(x: 2 * width, y: 0))
            path.addLine(to: CGPoint(x: 2 * width, y: size.height))
            context.stroke(path, with: .color(.gray), lineWidth: 1.5)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
