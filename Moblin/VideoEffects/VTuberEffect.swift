import UIKit
import VRMSceneKit

final class VTuberEffect: VideoEffect {
    init(vrm: URL) {
        do {
            let scene = try VRMSceneLoader(withURL: vrm).loadScene()
            logger.info("v-tuber: Scene \(scene)")
        } catch {
            logger.info("v-tuber: Failed to load VRM file with error: \(error)")
        }
    }

    override func getName() -> String {
        return "VTuber"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        return image
    }
}
