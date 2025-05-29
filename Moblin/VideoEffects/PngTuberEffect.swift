import SceneKit
import UIKit
import Vision
import VRMSceneKit

private class PngCoordinate: Decodable {
    let x: Double
    let y: Double

    required init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        if let match = value.firstMatch(of: /Vector2\(([-\d]+), ([-\d]+)\)/) {
            x = Double(match.1) ?? 0
            y = Double(match.2) ?? 0
        } else {
            x = 0
            y = 0
        }
    }
}

private class PngTuberImage: Decodable {
    // var animSpeed: Int
    // var clipped: Bool
    let costumeLayers: [Int]
    // var drag: Int
    // var frames: Int
    let identification: Int
    // var ignoreBounce: Bool
    let imageData: CIImage
    let offset: PngCoordinate
    let parentId: Int?
    // var path: String
    let pos: PngCoordinate
    // var rLimitMax: Int
    // var rLimitMin: Int
    // var rotDrag: Int
    let showBlink: Int
    let showTalk: Int
    // var stretchAmount: Float
    // var toggle: String
    // var type: PNGType
    // var xAmp: Int
    // var xFrq: Float
    // var yAmp: Int
    // var yFrq: Float
    let zindex: Int

    enum CodingKeys: CodingKey {
        case costumeLayers,
             identification,
             imageData,
             offset,
             parentId,
             pos,
             showBlink,
             showTalk,
             zindex
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let costumeLayersData = try container.decode(String.self, forKey: .costumeLayers).utf8Data
        costumeLayers = try JSONDecoder().decode([Int].self, from: costumeLayersData)
        guard costumeLayers.count == 10 else {
            throw "Not 10 costumes: \(costumeLayers.count)"
        }
        identification = try container.decode(Int.self, forKey: .identification)
        guard let imageDataData = try Data(base64Encoded: container.decode(String.self, forKey: .imageData).utf8Data),
              let cgImage = UIImage(data: imageDataData)?.cgImage
        else {
            throw "Failed to decode image data"
        }
        imageData = CIImage(cgImage: cgImage)
        offset = try container.decode(PngCoordinate.self, forKey: .offset)
        parentId = try container.decode(Int?.self, forKey: .parentId)
        pos = try container.decode(PngCoordinate.self, forKey: .pos)
        showBlink = try container.decode(Int.self, forKey: .showBlink)
        showTalk = try container.decode(Int.self, forKey: .showTalk)
        zindex = try container.decode(Int.self, forKey: .zindex)
    }
}

private class PngTuberFile {
    var images: [PngTuberImage]

    init(images: [PngTuberImage]) {
        self.images = images
    }
}

final class PngTuberEffect: VideoEffect {
    private let model: PngTuberFile?
    private var videoSourceId: UUID = .init()
    private var sceneWidget: SettingsSceneWidget?
    private var currentCostume = 1
    private var isMouthOpen = false
    private var isLeftEyeOpen = true

    init(model: URL) {
        do {
            let model = try JSONDecoder().decode([String: PngTuberImage].self, from: Data(contentsOf: model))
            let images = model.sorted(by: { Int($0.key) ?? 0 < Int($1.key) ?? 0 }).map { $0.value }
            self.model = PngTuberFile(images: images)
        } catch {
            logger.info("png-tuber: Failed to load model with error: \(error)")
            self.model = nil
        }
    }

    func setVideoSourceId(videoSourceId: UUID) {
        mixerLockQueue.async {
            self.videoSourceId = videoSourceId
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        mixerLockQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    override func getName() -> String {
        return "PNGTuber"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let model else {
            return image
        }
        updateModelPose(image: image, info: info)
        var pngTuberImage = image
        for image in model.images {
            guard shouldShowImage(image: image) else {
                continue
            }
            pngTuberImage = image.imageData
                .composited(over: pngTuberImage)
        }
        return pngTuberImage
    }

    private func shouldShowImage(image: PngTuberImage) -> Bool {
        guard image.costumeLayers[currentCostume - 1] == 1 else {
            return false
        }
        switch image.showBlink {
        case 1:
            return !isLeftEyeOpen
        case 2:
            return isLeftEyeOpen
        default:
            break
        }
        switch image.showTalk {
        case 1:
            return !isMouthOpen
        case 2:
            return isMouthOpen
        default:
            break
        }
        return true
    }

    private func updateModelPose(image: CIImage, info: VideoEffectInfo) {
        if let detection = info.faceDetections[videoSourceId]?.first,
           let rotationAngle = detection.calcFaceAngle(imageSize: image.extent.size)
        {
            isMouthOpen = detection.isMouthOpen(rotationAngle: rotationAngle) > 0.15
            isLeftEyeOpen = -(detection.isLeftEyeOpen(rotationAngle: rotationAngle) - 1) > 0.1
        }
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?, Double?) {
        return (false, videoSourceId, 0.1)
    }
}
