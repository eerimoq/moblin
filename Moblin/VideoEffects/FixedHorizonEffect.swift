import AVFoundation
import CoreMotion
import MetalPetal
import UIKit
import Vision

private func minimalBoundingRectWithAspect(width: CGFloat, height: CGFloat, angle: CGFloat) -> CGSize {
    let cosAngle = cos(angle)
    let sinAngle = sin(angle)
    var corners = [
        CGPoint(x: -width / 2, y: -height / 2),
        CGPoint(x: -width / 2, y: height / 2),
        CGPoint(x: width / 2, y: -height / 2),
        CGPoint(x: width / 2, y: height / 2),
    ]
    corners = corners.map {
        CGPoint(x: $0.x * cosAngle - $0.y * sinAngle, y: $0.x * sinAngle + $0.y * cosAngle)
    }
    let xs = corners.map { $0.x }
    let ys = corners.map { $0.y }
    let boxWidth = xs.max()! - xs.min()!
    let boxHeight = ys.max()! - ys.min()!
    let aspect = width / height
    let scaleWidth = max(boxWidth, boxHeight * aspect)
    let scaleHeight = max(boxHeight, boxWidth / aspect)
    return CGSize(width: scaleWidth, height: scaleHeight)
}

final class FixedHorizonEffect: VideoEffect {
    private var targetPitch: Double?
    private var targetX: Double?
    private var currentAngle = 0.0
    // Sometimes crashes on Mac in deinit() if instantiated here.
    private var motionManager: CMMotionManager?
    private var started = false
    private let operationQueue = OperationQueue()

    override init() {
        super.init()
        operationQueue.underlyingQueue = processorPipelineQueue
    }

    deinit {
        stop()
    }

    func start() {
        guard !started, !isMac() else {
            return
        }
        started = true
        motionManager = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 0.1
        motionManager?.startDeviceMotionUpdates(to: operationQueue) { [weak self] motion, _ in
            self?.targetPitch = motion?.attitude.pitch
            self?.targetX = motion?.gravity.x
        }
    }

    func stop() {
        guard started else {
            return
        }
        started = false
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
    }

    override func getName() -> String {
        return "fixed horizon"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let targetPitch, let targetX else {
            return image
        }
        let targetAngle: Double
        let targetWeight: Double
        if image.extent.width > image.extent.height {
            targetAngle = targetX > 0 ? targetPitch : -targetPitch
        } else {
            targetAngle = targetX > 0 ? targetPitch - .pi / 2 : -targetPitch + .pi / 2
        }
        if abs(targetX) < 0.1 {
            targetWeight = 2 * abs(targetX)
        } else {
            targetWeight = 0.2
        }
        currentAngle = targetWeight * targetAngle + (1 - targetWeight) * currentAngle
        let boundingSize = minimalBoundingRectWithAspect(
            width: image.extent.width,
            height: image.extent.height,
            angle: currentAngle
        )
        let scale = boundingSize.width / image.extent.width
        return image
            .transformed(by: CGAffineTransform(translationX: -image.extent.width / 2, y: -image.extent.height / 2))
            .transformed(by: CGAffineTransform(rotationAngle: currentAngle))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: image.extent.width / 2, y: image.extent.height / 2))
            .cropped(to: image.extent)
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
