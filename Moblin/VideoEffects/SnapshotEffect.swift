import Collections
import CoreImage
import MetalPetal

final class SnapshotEffect: VideoEffect, @unchecked Sendable {
    private var snapshots: Deque<CIImage> = []
    private var sceneWidget: SettingsSceneWidget?
    private var currentSnapshot: EffectImageCiImage?
    private var hideSnapshotTime: Double?
    private var showtime: Double

    init(showtime: Int) {
        self.showtime = Double(showtime)
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
            self.appendSnapshotInternal(image: image)
        }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget else {
            return image
        }
        updateCurrentSnapshot(info: info)
        guard let currentSnapshot else {
            return image
        }
        return applyEffectsResizeMirrorMove(currentSnapshot.getCiImage(),
                                            sceneWidget,
                                            false,
                                            image.extent,
                                            info)
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        guard let sceneWidget else {
            return image
        }
        updateCurrentSnapshot(info: info)
        guard let currentSnapshot else {
            return image
        }
        return applyEffectsResizeMirrorMoveMetalPetal(currentSnapshot.getMetalPetalImage(),
                                                      sceneWidget,
                                                      false,
                                                      image,
                                                      info)
    }

    override func isEnabled() -> Bool {
        currentSnapshot != nil
    }

    private func updateCurrentSnapshot(info: VideoEffectInfo) {
        if hideSnapshotTime == nil {
            hideSnapshotTime = info.presentationTimeStamp.seconds + showtime
        }
        if let hideSnapshotTime, info.presentationTimeStamp.seconds > hideSnapshotTime {
            setCurrentSnapshot(image: snapshots.popFirst())
            self.hideSnapshotTime = nil
        }
    }

    private func setCurrentSnapshot(image: CIImage?) {
        currentSnapshot = image?.toEffectImage(isOpaque: true)
    }

    private func appendSnapshotInternal(image: CIImage) {
        snapshots.append(image)
        guard currentSnapshot == nil else {
            return
        }
        setCurrentSnapshot(image: snapshots.popFirst())
        hideSnapshotTime = nil
    }
}
