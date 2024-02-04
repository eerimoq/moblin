import AVFoundation
import HaishinKit
import SwiftUI
import UIKit

private let drawQueue = DispatchQueue(label: "com.eerimoq.widget.text")

func drawOnStreamCreatePath(points: [CGPoint]) -> Path {
    var path = Path()
    if let firstPoint = points.first {
        path.move(to: firstPoint)
    }
    if points.count > 2 {
        for index in 1 ..< points.count {
            let mid = calculateMidPoint(points[index - 1], points[index])
            path.addQuadCurve(to: mid, control: points[index - 1])
        }
    }
    if let last = points.last {
        path.addLine(to: last)
    }
    return path
}

private func calculateMidPoint(_ point1: CGPoint, _ point2: CGPoint) -> CGPoint {
    return CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
}

private func transformPoint(point: CGPoint, scale: Double, offsetX: Double) -> CGPoint {
    return CGPoint(x: point.x * scale - offsetX, y: point.y * scale)
}

final class DrawOnStreamEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?

    func updateOverlay(videoSize: CGSize, size: CGSize, lines: [DrawOnStreamLine]) {
        DispatchQueue.main.async {
            let drawRatio = size.width / size.height
            let videoRatio = videoSize.width / videoSize.height
            let offsetX = (drawRatio / videoRatio * videoSize.width - videoSize.width) / 2
            let scale = videoSize.height / size.height
            let canvas = Canvas { context, _ in
                for line in lines {
                    let width = line.width * scale
                    if line.points.count > 1 {
                        context.stroke(
                            drawOnStreamCreatePath(points: line.points.map { point in
                                transformPoint(point: point, scale: scale, offsetX: offsetX)
                            }),
                            with: .color(line.color),
                            lineWidth: width
                        )
                    } else {
                        let point = transformPoint(point: line.points[0], scale: scale, offsetX: offsetX)
                        var path = Path()
                        path.addEllipse(in: CGRect(x: point.x, y: point.y, width: 1, height: 1))
                        context.stroke(path, with: .color(line.color), lineWidth: width)
                    }
                }
            }
            .background(.clear)
            .frame(width: videoSize.width, height: videoSize.height)
            let renderer = ImageRenderer(content: canvas)
            guard let uiImage = renderer.uiImage else {
                return
            }
            let image = CIImage(image: uiImage)
            drawQueue.sync {
                self.overlay = image
            }
        }
    }

    private func getOverlay() -> CIImage? {
        drawQueue.sync {
            overlay
        }
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        filter.inputImage = getOverlay()
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
