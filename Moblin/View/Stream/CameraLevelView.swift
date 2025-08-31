import CoreMotion
import SwiftUI

struct CameraLevelView: View {
    @ObservedObject var cameraLevel: CameraLevel

    var body: some View {
        Canvas { context, size in
            guard let angle = cameraLevel.angle else {
                return
            }
            let y = size.height / 2
            let xLeft: Double
            let xRight: Double
            if size.width > size.height {
                xLeft = size.width * 0.25
                xRight = size.width * 0.75
            } else {
                xLeft = size.width * 0.15
                xRight = size.width * 0.85
            }
            var path = Path()
            let color: Color
            if abs(angle) < 0.01 {
                path.move(to: CGPoint(x: xLeft, y: y))
                path.addLine(to: CGPoint(x: xRight, y: y))
                color = .yellow
            } else {
                // Left
                path.move(to: CGPoint(x: xLeft, y: y))
                path.addLine(to: CGPoint(x: xLeft + 25, y: y))
                // Right
                path.move(to: CGPoint(x: xRight - 25, y: y))
                path.addLine(to: CGPoint(x: xRight, y: y))
                // Middle
                if abs(angle) < 0.5 {
                    let lineLength = xRight - xLeft - 2 * 30
                    let xLine = cos(angle) * lineLength / 2
                    let yLine = sin(angle) * lineLength / 2
                    path.move(to: CGPoint(x: size.width / 2 - xLine, y: y - yLine))
                    path.addLine(to: CGPoint(x: size.width / 2 + xLine, y: y + yLine))
                }
                color = .gray
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}
