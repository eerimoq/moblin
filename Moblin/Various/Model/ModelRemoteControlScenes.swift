import Foundation
import ZipArchive

func unzipLive2DModel(from url: URL, to directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try ZipArchiveReader.withFile(url.path) { reader in
        try reader.extract(to: .init(directory.path))
    }
}

extension Model {
    func remoteControlGetScenes() -> [SettingsScene] {
        database.scenes
    }

    func remoteControlGetWidgets() -> [SettingsWidget] {
        database.widgets
    }

    func remoteControlCreateScene(scene: SettingsScene) -> Bool {
        guard !database.scenes.contains(where: { $0.id == scene.id }) else {
            return false
        }
        database.scenes.append(scene)
        removeDeadWidgetsFromScenes()
        remoteControlScenesChanged(sceneId: scene.id)
        return true
    }

    func remoteControlUpdateScene(scene: SettingsScene) -> Bool {
        guard let index = database.scenes.firstIndex(where: { $0.id == scene.id }) else {
            return false
        }
        database.scenes[index] = scene
        removeDeadWidgetsFromScenes()
        remoteControlScenesChanged(sceneId: scene.id)
        return true
    }

    func remoteControlDeleteScene(id: UUID) -> Bool {
        guard database.scenes.contains(where: { $0.id == id }) else {
            return false
        }
        database.scenes.removeAll { $0.id == id }
        remoteControlScenesChanged(sceneId: id)
        return true
    }

    func remoteControlReorderScenes(ids: [UUID]) -> Bool {
        guard let scenes = reorder(items: database.scenes, ids: ids) else {
            return false
        }
        database.scenes = scenes
        remoteControlScenesChanged(sceneId: nil)
        return true
    }

    func remoteControlCreateWidget(widget: SettingsWidget) -> Bool {
        guard !database.widgets.contains(where: { $0.id == widget.id }) else {
            return false
        }
        database.widgets.append(widget)
        remoteControlWidgetsChanged(widget: widget)
        return true
    }

    func remoteControlUpdateWidget(widget: SettingsWidget) -> Bool {
        guard let index = database.widgets.firstIndex(where: { $0.id == widget.id }) else {
            return false
        }
        database.widgets[index] = widget
        remoteControlWidgetsChanged(widget: widget)
        return true
    }

    func remoteControlDeleteWidget(id: UUID) -> Bool {
        guard database.widgets.contains(where: { $0.id == id }) else {
            return false
        }
        database.widgets.removeAll { $0.id == id }
        removeDeadWidgetsFromScenes()
        resetSelectedScene(changeScene: false)
        storeSettings()
        return true
    }

    func remoteControlReorderWidgets(ids: [UUID]) -> Bool {
        guard let widgets = reorder(items: database.widgets, ids: ids) else {
            return false
        }
        database.widgets = widgets
        storeSettings()
        return true
    }

    func remoteControlSetWidgetImage(id: UUID, image: Data) -> Bool {
        guard let widget = database.widgets.first(where: { $0.id == id }), widget.type == .image else {
            return false
        }
        imageStorage.write(id: id, data: image)
        imageWidgetUpdated(id: id)
        getImageEffect(id: id)?.loadImage(imageStorage: imageStorage, widgetId: id)
        return true
    }

    func remoteControlGetAlertsMediaGallery() -> SettingsAlertsMediaGallery {
        database.alertsMediaGallery
    }

    func remoteControlGetVideoSources() -> [RemoteControlVideoSource] {
        videoSources.all().map { camera in
            var videoSource = SettingsVideoSource()
            videoSource.updateCameraId(settingsCameraId: cameraIdToSettingsCameraId(cameraId: camera.id))
            return RemoteControlVideoSource(id: camera.id,
                                            name: camera.name,
                                            position: videoSource.cameraPosition)
        }
    }

    func remoteControlSetAlertImage(media: SettingsAlertsMediaGalleryItem, image: Data) -> Bool {
        let gallery = database.alertsMediaGallery
        guard !gallery.bundledImages.contains(where: { $0.id == media.id }) else {
            return false
        }
        if let index = gallery.customImages.firstIndex(where: { $0.id == media.id }) {
            gallery.customImages[index] = media
        } else {
            gallery.customImages.append(media)
        }
        alertMediaStorage.write(id: media.id, data: image)
        updateAlertsSettings()
        storeSettings()
        return true
    }

    func remoteControlSetAlertSound(media: SettingsAlertsMediaGalleryItem, sound: Data) -> Bool {
        let gallery = database.alertsMediaGallery
        guard !gallery.bundledSounds.contains(where: { $0.id == media.id }) else {
            return false
        }
        if let index = gallery.customSounds.firstIndex(where: { $0.id == media.id }) {
            gallery.customSounds[index] = media
        } else {
            gallery.customSounds.append(media)
        }
        alertMediaStorage.write(id: media.id, data: sound)
        updateAlertsSettings()
        storeSettings()
        return true
    }

    func remoteControlDeleteAlertMedia(id: UUID) -> Bool {
        let gallery = database.alertsMediaGallery
        guard gallery.customImages.contains(where: { $0.id == id })
            || gallery.customSounds.contains(where: { $0.id == id })
        else {
            return false
        }
        gallery.customImages.removeAll { $0.id == id }
        gallery.customSounds.removeAll { $0.id == id }
        alertMediaStorage.remove(id: id)
        fixAlertMedias()
        storeSettings()
        return true
    }

    func remoteControlSetAlertVideo(alertId: UUID, videoName: String, video: Data) -> Bool {
        guard let filename = SettingsWidgetAlertsAlert.makeVideoFilename(id: alertId, videoName: videoName)
        else {
            return false
        }
        alertMediaStorage.videos.remove(filename: filename)
        do {
            try video.write(to: alertMediaStorage.videos.makePath(filename: filename))
        } catch {
            logger.info("remote-control-streamer: Alert video write failed with error \(error)")
            return false
        }
        updateAlertsSettings()
        return true
    }

    func remoteControlSetVTuberModel(id: UUID,
                                     type: SettingsWidgetVTuberType,
                                     model: Data,
                                     onCompleted: @escaping @MainActor (Bool) -> Void)
    {
        switch type {
        case .vrm:
            vTuberStorage.write(id: id, data: model)
            resetSelectedScene(changeScene: false)
            onCompleted(true)
        case .live2D:
            let temporaryDirectory = FileManager.default.temporaryDirectory
            let zipUrl = temporaryDirectory.appending(path: UUID().uuidString)
            let directory = temporaryDirectory.appending(path: UUID().uuidString)
            DispatchQueue.global().async {
                do {
                    try model.write(to: zipUrl)
                    try unzipLive2DModel(from: zipUrl, to: directory)
                    try? FileManager.default.removeItem(at: zipUrl)
                } catch {
                    logger.info("remote-control-streamer: Live2D model unzip failed with error \(error)")
                    DispatchQueue.main.async {
                        onCompleted(false)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.vTuberStorage.add(id: id, url: directory)
                    self.resetSelectedScene(changeScene: false)
                    onCompleted(true)
                }
            }
        }
    }

    func remoteControlSetPngTuberModel(id: UUID, model: Data) -> Bool {
        pngTuberStorage.write(id: id, data: model)
        resetSelectedScene(changeScene: false)
        return true
    }

    private func remoteControlScenesChanged(sceneId: UUID?) {
        let selectedSceneId = sceneSelector.selectedSceneId
        if findEnabledScene(id: selectedSceneId) == nil {
            sceneSelector.sceneIndex = 0
            resetSelectedScene()
        } else {
            sceneSelector.sceneIndex = findEnabledSceneIndex(id: selectedSceneId) ?? 0
            sceneUpdated(attachCamera: sceneId == selectedSceneId)
            if sceneId == selectedSceneId {
                switchMicIfNeededAfterSceneSwitch()
            }
        }
        storeSettings()
    }

    private func remoteControlWidgetsChanged(widget: SettingsWidget) {
        fixAlertMedias()
        resetSelectedScene(changeScene: false, attachCamera: isCaptureDeviceWidget(widget: widget))
        switch widget.type {
        case .text:
            textWidgetTextChanged(widget: widget)
        case .wheelOfLuck:
            updateWheelOfLuckEffect(widget: widget)
        default:
            break
        }
        storeSettings()
    }

    private func reorder<T: Identifiable>(items: [T], ids: [UUID]) -> [T]? where T.ID == UUID {
        guard ids.count == items.count, Set(ids).count == ids.count else {
            return nil
        }
        var reordered: [T] = []
        for id in ids {
            guard let item = items.first(where: { $0.id == id }) else {
                return nil
            }
            reordered.append(item)
        }
        return reordered
    }
}
