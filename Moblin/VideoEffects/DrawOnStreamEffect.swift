import AVFoundation
import MetalPetal
import SwiftUI
import UIKit
import Vision

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

final class DrawOnStreamEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?

    override func getName() -> String {
        return "draw on stream"
    }

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
            let canvas = Canvas { context, _ in
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
            let renderer = ImageRenderer(content: canvas)
            guard let uiImage = renderer.uiImage else {
                return
            }
            let image = CIImage(image: uiImage)
            guard let cgImage = uiImage.cgImage else {
                return
            }
            let imageMetalPetal = MTIImage(cgImage: cgImage, isOpaque: true)
            drawQueue.sync {
                self.overlay = image
                self.overlayMetalPetal = imageMetalPetal
            }
        }
    }

    private func getOverlay() -> CIImage? {
        drawQueue.sync {
            overlay
        }
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        filter.inputImage = getOverlay()
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    private func getOverlayMetalPetal() -> MTIImage? {
        drawQueue.sync {
            overlayMetalPetal
        }
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let overlay = getOverlayMetalPetal() else {
            return image
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlay, position: .init(x: overlay.size.width / 2, y: overlay.size.height / 2)),
        ]
        return filter.outputImage ?? image
    }
}
