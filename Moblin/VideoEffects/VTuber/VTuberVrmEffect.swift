import CoreVideo
import Metal
import RealityKit
import VRMRealityKit

private struct VTuberVrmPose {
    var face = VTuberFace()
    var time = 0.0
    var timeDelta = 0.0
    var armsAngle = Double.pi / 2.5
}

private struct VTuberVrmBoneRest {
    let orientation: simd_quatf
    let parentOrientation: simd_quatf
}

@available(iOS 18.0, *)
@MainActor
private final class VTuberVrmRenderer {
    private let entity: VRMEntity
    private let renderer: RealityRenderer
    private let camera: PerspectiveCamera
    private let device: MTLDevice
    private let boneRests: [HumanoidBone: VTuberVrmBoneRest]
    private let mouthOpen: ExpressionHandle?
    private let blink: ExpressionHandle?
    private var weights: ExpressionWeights
    private var textureCache: CVMetalTextureCache?
    private var pool: CVPixelBufferPool?
    private var poolSize = 0

    private init(entity: VRMEntity, renderer: RealityRenderer, device: MTLDevice) {
        self.entity = entity
        self.renderer = renderer
        self.device = device
        camera = PerspectiveCamera()
        camera.camera.fieldOfViewOrientation = .vertical
        if entity.frontDirection.z > 0 {
            entity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        }
        var boneRests: [HumanoidBone: VTuberVrmBoneRest] = [:]
        for bone in [HumanoidBone.neck, .spine, .leftUpperArm, .rightUpperArm] {
            if let node = entity.humanoid.node(for: bone) {
                boneRests[bone] = VTuberVrmBoneRest(
                    orientation: node.orientation,
                    parentOrientation: node.parent?.orientation(relativeTo: nil) ?? simd_quatf(
                        ix: 0,
                        iy: 0,
                        iz: 0,
                        r: 1
                    )
                )
            }
        }
        self.boneRests = boneRests
        mouthOpen = entity.expressionHandle(for: .preset(.aa))
        blink = entity.expressionHandle(for: .preset(.blink))
        weights = entity.makeExpressionWeights()
        entity.isAutomaticUpdateEnabled = false
        camera.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        let light = DirectionalLight()
        light.look(at: [0, 1, 0], from: [0, 2, -2], relativeTo: nil)
        renderer.entities.append(entity)
        renderer.entities.append(camera)
        renderer.entities.append(light)
        renderer.activeCamera = camera
        renderer.cameraSettings.isToneMappingEnabled = false
        renderer.cameraSettings.antialiasing = .multisample4X
        renderer.cameraSettings.colorBackground = .color(CGColor(gray: 0, alpha: 0))
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }

    static func load(vrm: URL) async -> VTuberVrmRenderer? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        do {
            let loader = try VRMEntityLoader(withURL: vrm,
                                             maxTextureDimension: 2048,
                                             outputColorSpace: .sRGB,
                                             compensatesToneMapping: false)
            let entity = try await loader.loadEntity()
            return try VTuberVrmRenderer(entity: entity, renderer: RealityRenderer(), device: device)
        } catch {
            logger.info("v-tuber: Failed to load VRM file with error: \(error)")
            return nil
        }
    }

    func setCamera(fieldOfView: Double, positionY: Double) {
        camera.camera.fieldOfViewInDegrees = Float(fieldOfView)
        camera.position = [0, Float(positionY), -1.8]
    }

    func render(pose: VTuberVrmPose, size: Int, onComplete: @escaping @Sendable (CVPixelBuffer?) -> Void) {
        update(pose: pose)
        guard let pixelBuffer = makePixelBuffer(size: size),
              let texture = makeTexture(pixelBuffer: pixelBuffer),
              let metalTexture = CVMetalTextureGetTexture(texture)
        else {
            onComplete(nil)
            return
        }
        let renderedPixelBuffer = RenderedPixelBuffer(pixelBuffer: pixelBuffer, texture: texture)
        do {
            let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: metalTexture))
            try renderer.updateAndRender(deltaTime: pose.timeDelta, cameraOutput: output, onComplete: { _ in
                onComplete(renderedPixelBuffer.pixelBuffer)
            })
        } catch {
            logger.info("v-tuber: Failed to render VRM with error: \(error)")
            onComplete(nil)
        }
    }

    private func update(pose: VTuberVrmPose) {
        let face = pose.face
        if let mouthOpen {
            weights[mouthOpen] = Float(face.mouthOpen)
        }
        if let blink {
            weights[blink] = Float(1 - face.leftEyeOpen)
        }
        entity.setExpressions(weights)
        let neckYAngle = face.sideAngle * 0.8
        let neckZAngle = face.rotationAngle * 0.8
        setBone(.neck, yAngle: -neckYAngle, zAngle: -neckZAngle)
        setBone(.spine, yAngle: -neckYAngle / 3, zAngle: -neckZAngle / 3)
        var angle = pose.time.remainder(dividingBy: .pi * 2)
        if angle < 0 {
            angle *= -1
        }
        angle -= .pi / 2
        angle *= 0.5
        let armAngle = (angle * 0.1) + pose.armsAngle
        setBone(.leftUpperArm, yAngle: 0, zAngle: armAngle)
        setBone(.rightUpperArm, yAngle: 0, zAngle: -armAngle)
        entity.update(deltaTime: pose.timeDelta)
    }

    private func setBone(_ bone: HumanoidBone, yAngle: Double, zAngle: Double) {
        guard let node = entity.humanoid.node(for: bone), let rest = boneRests[bone] else {
            return
        }
        let rotation = simd_quatf(angle: Float(yAngle), axis: [0, 1, 0])
            * simd_quatf(angle: Float(zAngle), axis: [0, 0, 1])
        node.orientation = rest.parentOrientation.inverse
            * rotation
            * rest.parentOrientation
            * rest.orientation
    }

    private func makePixelBuffer(size: Int) -> CVPixelBuffer? {
        if size != poolSize {
            let attributes: [NSString: AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
                kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferWidthKey: NSNumber(value: size),
                kCVPixelBufferHeightKey: NSNumber(value: size),
                kCVPixelBufferPoolMinimumBufferCountKey: NSNumber(value: 3),
            ]
            pool = nil
            CVPixelBufferPoolCreate(nil, nil, attributes as NSDictionary, &pool)
            poolSize = size
        }
        guard let pool else {
            return nil
        }
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess else {
            return nil
        }
        return pixelBuffer
    }

    private func makeTexture(pixelBuffer: CVPixelBuffer) -> CVMetalTexture? {
        guard let textureCache else {
            return nil
        }
        var texture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  textureCache,
                                                  pixelBuffer,
                                                  nil,
                                                  .bgra8Unorm_srgb,
                                                  CVPixelBufferGetWidth(pixelBuffer),
                                                  CVPixelBufferGetHeight(pixelBuffer),
                                                  0,
                                                  &texture)
        return texture
    }
}

private struct RenderedPixelBuffer: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let texture: CVMetalTexture
}

@available(iOS 18.0, *)
final class VTuberVrmEffect: VTuberEffect, @unchecked Sendable {
    private var renderer: VTuberVrmRenderer?
    private var pose = VTuberVrmPose()
    private var cameraFieldOfView: Double
    private var cameraPositionY: Double
    private var rendering = false
    private var renderedImage: EffectImage?

    init(vrm: URL, cameraFieldOfView: Double, cameraPositionY: Double) {
        self.cameraFieldOfView = cameraFieldOfView
        self.cameraPositionY = cameraPositionY
        super.init()
        Task { @MainActor in
            guard let renderer = await VTuberVrmRenderer.load(vrm: vrm) else {
                return
            }
            processorPipelineQueue.async {
                self.renderer = renderer
                self.updateCamera()
            }
        }
    }

    override func setModelSettings(cameraFieldOfView: Double, cameraPositionY: Double, armsAngle: Double) {
        self.cameraFieldOfView = cameraFieldOfView
        self.cameraPositionY = cameraPositionY
        pose.armsAngle = armsAngle.toRadians()
        updateCamera()
    }

    private func updateCamera() {
        guard let renderer else {
            return
        }
        let cameraFieldOfView = cameraFieldOfView
        let cameraPositionY = cameraPositionY
        DispatchQueue.main.async {
            renderer.setCamera(fieldOfView: cameraFieldOfView, positionY: cameraPositionY)
        }
    }

    override func isModelLoaded() -> Bool {
        renderer != nil
    }

    override func updateModel(face: VTuberFace, time: Double, timeDelta: Double) {
        pose.face = face
        pose.time = time
        pose.timeDelta += timeDelta
    }

    override func renderModel(time _: Double, size: CGSize) -> EffectImage? {
        guard let renderer, let sceneWidget else {
            return nil
        }
        if !rendering {
            rendering = true
            let pose = pose
            self.pose.timeDelta = 0
            let layoutSize = sceneWidget.layout.size
            let side = min(toPixels(layoutSize, size.width), toPixels(layoutSize, size.height))
            let size = 2 * Int(side.clamped(to: 64 ... 2048) / 2)
            DispatchQueue.main.async {
                renderer.render(pose: pose, size: size) { pixelBuffer in
                    processorPipelineQueue.async {
                        if let pixelBuffer {
                            self.renderedImage = EffectImagePixelBuffer(pixelBuffer: pixelBuffer)
                        }
                        self.rendering = false
                    }
                }
            }
        }
        return renderedImage
    }
}
