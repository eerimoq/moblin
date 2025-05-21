import AVFoundation
import CoreMotion
import MetalPetal
import UIKit
import Vision

private func minimalBoundingRectWithAspect(width w: CGFloat, height h: CGFloat, angle: CGFloat) -> CGSize {
    let cosTheta = cos(angle)
    let sinTheta = sin(angle)
    let corners = [
        CGPoint(x: -w / 2, y: -h / 2),
        CGPoint(x: -w / 2, y: h / 2),
        CGPoint(x: w / 2, y: -h / 2),
        CGPoint(x: w / 2, y: h / 2),
    ]
    let rotatedCorners = corners.map { corner -> CGPoint in
        CGPoint(
            x: corner.x * cosTheta - corner.y * sinTheta,
            y: corner.x * sinTheta + corner.y * cosTheta
        )
    }
    let xs = rotatedCorners.map { $0.x }
    let ys = rotatedCorners.map { $0.y }
    let minX = xs.min()!
    let maxX = xs.max()!
    let minY = ys.min()!
    let maxY = ys.max()!
    let boxWidth = maxX - minX
    let boxHeight = maxY - minY
    let aspect = w / h
    let scaleWidth = max(boxWidth, boxHeight * aspect)
    let scaleHeight = max(boxHeight, boxWidth / aspect)
    return CGSize(width: scaleWidth, height: scaleHeight)
}

final class HorizonEffect: VideoEffect {
    private var targetAngle = 0.0
    private var angle = 0.0
    private let motionManager = CMMotionManager()
    private var started = false

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }

    func start() {
        guard !started else {
            return
        }
        started = true
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            logger.info("xxx")
            guard let attitude = motion?.attitude else {
                return
            }
            guard let self else {
                return
            }
            self.targetAngle = -attitude.pitch
        }
    }

    func stop() {
        guard started else {
            return
        }
        started = false
        motionManager.stopDeviceMotionUpdates()
    }

    override func getName() -> String {
        return "horizon"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        angle = 0.2 * targetAngle + 0.8 * angle
        let boundingSize = minimalBoundingRectWithAspect(
            width: image.extent.width,
            height: image.extent.height,
            angle: angle
        )
        let scale = boundingSize.width / image.extent.width
        return image
            .transformed(by: CGAffineTransform(translationX: -image.extent.width / 2, y: -image.extent.height / 2))
            .transformed(by: CGAffineTransform(rotationAngle: angle))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: image.extent.width / 2, y: image.extent.height / 2))
            .cropped(to: image.extent)
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
