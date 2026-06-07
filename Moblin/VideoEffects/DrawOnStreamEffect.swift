import CoreImage
import SwiftUI

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
    CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
}

private func transformPoint(
    _ point: CGPoint,
    _ scale: Double,
    _ offsetX: Double,
    _ offsetY: Double,
    _ mirror: Bool,
    _ videoWidth: Double
) -> CGPoint {
    var x = point.x * scale - offsetX
    if mirror {
        x = videoWidth - x
    }
    return CGPoint(x: x, y: point.y * scale - offsetY)
}

final class DrawOnStreamEffect: VideoEffect, @unchecked Sendable {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?
    private var uiOverlay: CIImage?

    func updateOverlay(videoSize: CGSize, size: CGSize, lines: [DrawOnStreamLine], mirror: Bool) {
        DispatchQueue.main.async {
            let drawRatio = size.width / size.height
            let videoRatio = videoSize.width / videoSize.height
            var offsetX: Double
            var offsetY: Double
            var scale: Double
            if drawRatio > videoRatio {
                offsetX = (drawRatio / videoRatio * videoSize.width - videoSize.width) / 2
                offsetY = 0
                scale = videoSize.height / size.height
            } else {
                offsetX = 0
                offsetY = (videoRatio / drawRatio * videoSize.height - videoSize.height) / 2
                scale = videoSize.width / size.width
            }
            let streamCanvas = Canvas { context, _ in
                for line in lines {
                    let width = line.width * scale
                    if line.points.count > 1 {
                        context.stroke(
                            drawOnStreamCreatePath(points: line.points.map { point in
                                transformPoint(point, scale, offsetX, offsetY, mirror, videoSize.width)
                            }),
                            with: .color(line.color),
                            lineWidth: width
                        )
                    } else {
                        let point = transformPoint(
                            line.points[0],
                            scale,
                            offsetX,
                            offsetY,
                            mirror,
                            videoSize.width
                        )
                        var path = Path()
                        path.addEllipse(in: CGRect(x: point.x, y: point.y, width: 1, height: 1))
                        context.stroke(path, with: .color(line.color), lineWidth: width)
                    }
                }
            }
            .background(.clear)
            .frame(width: videoSize.width, height: videoSize.height)
            let streamRenderer = ImageRenderer(content: streamCanvas)
            let streamImage = streamRenderer.uiImage.flatMap { CIImage(image: $0) }
            var uiImage: CIImage?
            if mirror {
                let uiCanvas = Canvas { context, _ in
                    for line in lines {
                        let width = line.width * scale
                        if line.points.count > 1 {
                            context.stroke(
                                drawOnStreamCreatePath(points: line.points.map { point in
                                    transformPoint(point, scale, offsetX, offsetY, false, videoSize.width)
                                }),
                                with: .color(line.color),
                                lineWidth: width
                            )
                        } else {
                            let point = transformPoint(
                                line.points[0],
                                scale,
                                offsetX,
                                offsetY,
                                false,
                                videoSize.width
                            )
                            var path = Path()
                            path.addEllipse(in: CGRect(x: point.x, y: point.y, width: 1, height: 1))
                            context.stroke(path, with: .color(line.color), lineWidth: width)
                        }
                    }
                }
                .background(.clear)
                .frame(width: videoSize.width, height: videoSize.height)
                let uiRenderer = ImageRenderer(content: uiCanvas)
                uiImage = uiRenderer.uiImage.flatMap { CIImage(image: $0) }
            }
            processorPipelineQueue.async {
                self.overlay = streamImage
                self.uiOverlay = uiImage
            }
        }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let activeOverlay = info.isForUI ? (uiOverlay ?? overlay) : overlay
        filter.inputImage = activeOverlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
