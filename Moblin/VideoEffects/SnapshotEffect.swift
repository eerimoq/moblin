import AVFoundation
import Collections
import UIKit
import Vision

protocol SnapshotEffectDelegate: AnyObject {
    func snapshotEffectRegisterVideoEffect(effect: VideoEffect)
}

final class SnapshotEffect: VideoEffect {
    private var snapshots: Deque<CIImage> = []
    private var sceneWidget: SettingsSceneWidget?
    private var currentSnapshot: CIImage?
    private var hideSnapshotTime: Double?
    private weak var delegate: SnapshotEffectDelegate?

    init(delegate: SnapshotEffectDelegate) {
        self.delegate = delegate
        super.init()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func appendSnapshot(image: CIImage) {
        processorPipelineQueue.async {
            self.appendSnapshotInner(image: image)
        }
    }

    private func appendSnapshotInner(image: CIImage) {
        snapshots.append(image)
        guard currentSnapshot == nil else {
            return
        }
        currentSnapshot = snapshots.popFirst()
        hideSnapshotTime = nil
        delegate?.snapshotEffectRegisterVideoEffect(effect: self)
    }

    override func getName() -> String {
        return "snapshot widget"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget else {
            return image
        }
        if hideSnapshotTime == nil {
            hideSnapshotTime = info.presentationTimeStamp.seconds + 5
        }
        if let hideSnapshotTime, info.presentationTimeStamp.seconds > hideSnapshotTime {
            self.currentSnapshot = snapshots.popFirst()
            self.hideSnapshotTime = nil
            return image
        }
        guard let currentSnapshot else {
            return image
        }
        return applyEffects(currentSnapshot, info)
            .resizeMoveMirror(sceneWidget, image.extent.size, false)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    override func shouldRemove() -> Bool {
        return currentSnapshot == nil
    }
}
