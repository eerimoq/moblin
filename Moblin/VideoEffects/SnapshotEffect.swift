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
    private var showtime: Double
    private weak var delegate: SnapshotEffectDelegate?

    init(showtime: Int, delegate: SnapshotEffectDelegate) {
        self.showtime = Double(showtime)
        self.delegate = delegate
        super.init()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setSettings(showtime: Int) {
        processorPipelineQueue.async {
            self.showtime = Double(showtime)
        }
    }

    func appendSnapshot(image: CIImage) {
        processorPipelineQueue.async {
            self.appendSnapshotInner(image: image)
        }
    }

    func removeSnapshots() {
        processorPipelineQueue.async {
            self.removeSnapshotsInner()
        }
    }

    override func getName() -> String {
        return "snapshot widget"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget else {
            return image
        }
        if hideSnapshotTime == nil {
            hideSnapshotTime = info.presentationTimeStamp.seconds + showtime
        }
        if let hideSnapshotTime, info.presentationTimeStamp.seconds > hideSnapshotTime {
            self.currentSnapshot = snapshots.popFirst()
            self.hideSnapshotTime = nil
        }
        guard let currentSnapshot else {
            return image
        }
        return applyEffectsResizeMirrorMove(currentSnapshot, sceneWidget, false, image.extent, info)
            .composited(over: image)
    }

    override func shouldRemove() -> Bool {
        return currentSnapshot == nil
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

    private func removeSnapshotsInner() {
        snapshots.removeAll()
        currentSnapshot = nil
        hideSnapshotTime = nil
    }
}
