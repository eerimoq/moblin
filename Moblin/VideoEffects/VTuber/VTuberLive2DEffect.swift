import Ayagami
import CoreVideo

private struct Live2DLoaded: @unchecked Sendable {
    let model: AyagamiModel
    let renderer: Live2DRenderer
    let pool: CVPixelBufferPool
}

final class VTuberLive2DEffect: VTuberEffect, @unchecked Sendable {
    private var loaded: Live2DLoaded?

    init(directory: URL) {
        super.init()
        DispatchQueue.global().async {
            guard let loaded = Self.load(directory: directory) else {
                return
            }
            processorPipelineQueue.async {
                self.loaded = loaded
            }
        }
    }

    private static func load(directory: URL) -> Live2DLoaded? {
        guard let model3Url = findModel3(directory: directory) else {
            logger.info("v-tuber: No model3.json found")
            return nil
        }
        let model: AyagamiModel
        do {
            model = try AyagamiModel(model3Url: model3Url)
        } catch {
            logger.info("v-tuber: Failed to load Live2D model with error: \(error)")
            return nil
        }
        guard let renderer = Live2DRenderer(model: model) else {
            return nil
        }
        guard model.canvas.dimensions.x > 0, model.canvas.dimensions.y > 0 else {
            logger.info("v-tuber: Bad Live2D canvas dimensions \(model.canvas.dimensions)")
            return nil
        }
        let height = 800
        let width = 2 *
            Int(Double(height) * Double(model.canvas.dimensions.x / model.canvas.dimensions.y) / 2)
        let attributes: [NSString: AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferWidthKey: NSNumber(value: width),
            kCVPixelBufferHeightKey: NSNumber(value: height),
            kCVPixelBufferPoolMinimumBufferCountKey: NSNumber(value: 3),
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, attributes as NSDictionary, &pool)
        guard let pool else {
            return nil
        }
        return Live2DLoaded(model: model, renderer: renderer, pool: pool)
    }

    private static func findModel3(directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        else {
            return nil
        }
        for case let url as URL in enumerator {
            if url.lastPathComponent.hasSuffix(".model3.json"), !url.path.contains("__MACOSX") {
                return url
            }
        }
        return nil
    }

    override func isModelLoaded() -> Bool {
        loaded != nil
    }

    override func updateModel(face: VTuberFace, time: Double, timeDelta: Double) {
        guard let model = loaded?.model else {
            return
        }
        let angleX = face.sideAngle * 30
        model.setParameter("ParamAngleX", Float(angleX))
        model.setParameter("ParamAngleZ", Float(-face.rotationAngle.toDegrees()))
        model.setParameter("ParamBodyAngleX", Float(angleX / 3))
        model.setParameter("ParamMouthOpenY", Float(face.mouthOpen))
        model.setParameter("ParamEyeLOpen", Float(face.leftEyeOpen))
        model.setParameter("ParamEyeROpen", Float(face.rightEyeOpen))
        model.setParameter("ParamBreath", Float(0.5 - cos(time / 2 * .pi) / 2))
        model.update(deltaTime: Float(timeDelta))
    }

    override func renderModel(time _: Double, size _: CGSize) -> EffectImage? {
        guard let loaded else {
            return nil
        }
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, loaded.pool, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer
        else {
            return nil
        }
        loaded.renderer.render(model: loaded.model, into: pixelBuffer)
        return EffectImagePixelBuffer(pixelBuffer: pixelBuffer)
    }
}
