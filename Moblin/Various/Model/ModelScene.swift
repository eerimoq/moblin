import AVFoundation
import CoreLocation
import SwiftUI

extension Model {
    private func reloadImageEffects() {
        imageEffects.removeAll()
        for widget in database.widgets where widget.type == .image {
            guard let data = imageStorage.read(id: widget.id) else {
                continue
            }
            guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
                continue
            }
            let imageEffect = ImageEffect(
                image: image,
                settingName: widget.name,
                widgetId: widget.id
            )
            imageEffect.effects = widget.getEffects()
            imageEffects[widget.id] = imageEffect
        }
    }

    private func unregisterGlobalVideoEffects() {
        media.unregisterEffect(faceEffect)
        media.unregisterEffect(movieEffect)
        media.unregisterEffect(grayScaleEffect)
        media.unregisterEffect(sepiaEffect)
        media.unregisterEffect(tripleEffect)
        media.unregisterEffect(twinEffect)
        media.unregisterEffect(pixellateEffect)
        media.unregisterEffect(pollEffect)
        media.unregisterEffect(whirlpoolEffect)
        media.unregisterEffect(pinchEffect)
        media.unregisterEffect(fixedHorizonEffect)
        faceEffect = FaceEffect(fps: Float(stream.fps), onFindFaceChanged: handleFindFaceChanged(value:))
        updateFaceFilterSettings()
        movieEffect = MovieEffect()
        grayScaleEffect = GrayScaleEffect()
        sepiaEffect = SepiaEffect()
        tripleEffect = TripleEffect()
        twinEffect = TwinEffect()
        pixellateEffect = PixellateEffect(strength: database.pixellateStrength)
        pollEffect = PollEffect()
        whirlpoolEffect = WhirlpoolEffect(angle: database.whirlpoolAngle)
        pinchEffect = PinchEffect(scale: database.pinchScale)
        fixedHorizonEffect = FixedHorizonEffect()
    }

    private func registerGlobalVideoEffects(scene: SettingsScene) -> [VideoEffect] {
        var effects: [VideoEffect] = []
        if isFixedHorizonEnabled(scene: scene) {
            fixedHorizonEffect.start()
            fixedHorizonStatus = "Enabled"
            effects.append(fixedHorizonEffect)
        } else {
            fixedHorizonStatus = "Disabled"
            fixedHorizonEffect.stop()
        }
        if isFaceEnabled() {
            effects.append(faceEffect)
        }
        if isGlobalButtonOn(type: .whirlpool) {
            effects.append(whirlpoolEffect)
        }
        if isGlobalButtonOn(type: .pinch) {
            effects.append(pinchEffect)
        }
        if isGlobalButtonOn(type: .movie) {
            effects.append(movieEffect)
        }
        if isGlobalButtonOn(type: .fourThree) {
            effects.append(fourThreeEffect)
        }
        if isGlobalButtonOn(type: .grayScale) {
            effects.append(grayScaleEffect)
        }
        if isGlobalButtonOn(type: .sepia) {
            effects.append(sepiaEffect)
        }
        if isGlobalButtonOn(type: .triple) {
            effects.append(tripleEffect)
        }
        if isGlobalButtonOn(type: .twin) {
            effects.append(twinEffect)
        }
        if isGlobalButtonOn(type: .pixellate) {
            pixellateEffect.setSettings(strength: database.pixellateStrength)
            effects.append(pixellateEffect)
        }
        return effects
    }

    private func registerGlobalVideoEffectsOnTop() -> [VideoEffect] {
        var effects: [VideoEffect] = []
        if isGlobalButtonOn(type: .poll) {
            effects.append(pollEffect)
        }
        return effects
    }

    func getTextEffect(id: UUID) -> TextEffect? {
        for (textEffectId, textEffect) in textEffects where id == textEffectId {
            return textEffect
        }
        return nil
    }

    func getVideoSourceEffect(id: UUID) -> VideoSourceEffect? {
        for (videoSourceEffectId, videoSourceEffect) in videoSourceEffects where id == videoSourceEffectId {
            return videoSourceEffect
        }
        return nil
    }

    func getVTuberEffect(id: UUID) -> VTuberEffect? {
        for (vTuberEffectId, vTuberEffect) in vTuberEffects where id == vTuberEffectId {
            return vTuberEffect
        }
        return nil
    }

    func getPngTuberEffect(id: UUID) -> PngTuberEffect? {
        for (pngTuberEffectId, pngTuberEffect) in pngTuberEffects where id == pngTuberEffectId {
            return pngTuberEffect
        }
        return nil
    }

    private func getImageEffect(id: UUID) -> ImageEffect? {
        for (imageEffectId, imageEffect) in imageEffects where id == imageEffectId {
            return imageEffect
        }
        return nil
    }

    private func getBrowserEffect(id: UUID) -> BrowserEffect? {
        for (browserEffectId, browserEffect) in browserEffects where id == browserEffectId {
            return browserEffect
        }
        return nil
    }

    private func getMapEffect(id: UUID) -> MapEffect? {
        for (mapEffectId, mapEffect) in mapEffects where id == mapEffectId {
            return mapEffect
        }
        return nil
    }

    func getEffectWithPossibleEffects(id: UUID) -> VideoEffect? {
        return getVideoSourceEffect(id: id)
            ?? getImageEffect(id: id)
            ?? getBrowserEffect(id: id)
            ?? getMapEffect(id: id)
    }

    func getVideoSourceSettings(id: UUID) -> SettingsWidget? {
        return database.widgets.first(where: { $0.id == id })
    }

    private func resetVideoEffects(widgets: [SettingsWidget]) {
        unregisterGlobalVideoEffects()
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        textEffects.removeAll()
        for widget in widgets where widget.type == .text {
            textEffects[widget.id] = TextEffect(
                format: widget.text.formatString,
                backgroundColor: widget.text.backgroundColor,
                foregroundColor: widget.text.foregroundColor,
                fontSize: CGFloat(widget.text.fontSize),
                fontDesign: widget.text.fontDesign.toSystem(),
                fontWeight: widget.text.fontWeight.toSystem(),
                fontMonospacedDigits: widget.text.fontMonospacedDigits,
                horizontalAlignment: widget.text.horizontalAlignment.toSystem(),
                verticalAlignment: widget.text.verticalAlignment.toSystem(),
                settingName: widget.name,
                delay: widget.text.delay,
                timersEndTime: widget.text.timers.map {
                    .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
                },
                checkboxes: widget.text.checkboxes.map { $0.checked },
                ratings: widget.text.ratings.map { $0.rating },
                lapTimes: widget.text.lapTimes.map { $0.lapTimes }
            )
        }
        for browserEffect in browserEffects.values {
            media.unregisterEffect(browserEffect)
            browserEffect.stop()
        }
        browserEffects.removeAll()
        for widget in widgets where widget.type == .browser {
            let videoSize = media.getVideoSize()
            guard let url = URL(string: widget.browser.url) else {
                continue
            }
            let browserEffect = BrowserEffect(
                url: url,
                styleSheet: widget.browser.styleSheet!,
                widget: widget.browser,
                videoSize: videoSize,
                settingName: widget.name,
                moblinAccess: widget.browser.moblinAccess!
            )
            browserEffect.effects = widget.getEffects()
            browserEffects[widget.id] = browserEffect
        }
        for mapEffect in mapEffects.values {
            media.unregisterEffect(mapEffect)
        }
        mapEffects.removeAll()
        for widget in widgets where widget.type == .map {
            let mapEffect = MapEffect(widget: widget.map)
            mapEffect.effects = widget.getEffects()
            mapEffects[widget.id] = mapEffect
        }
        for qrCodeEffect in qrCodeEffects.values {
            media.unregisterEffect(qrCodeEffect)
        }
        qrCodeEffects.removeAll()
        for widget in widgets where widget.type == .qrCode {
            qrCodeEffects[widget.id] = QrCodeEffect(widget: widget.qrCode)
        }
        for videoSourceEffect in videoSourceEffects.values {
            media.unregisterEffect(videoSourceEffect)
        }
        videoSourceEffects.removeAll()
        for widget in widgets where widget.type == .videoSource {
            let videoSourceEffect = VideoSourceEffect()
            videoSourceEffect.effects = widget.getEffects()
            videoSourceEffects[widget.id] = videoSourceEffect
        }
        for padelScoreboardEffect in padelScoreboardEffects.values {
            media.unregisterEffect(padelScoreboardEffect)
        }
        padelScoreboardEffects.removeAll()
        for widget in widgets where widget.type == .scoreboard {
            padelScoreboardEffects[widget.id] = PadelScoreboardEffect()
        }
        for alertsEffect in alertsEffects.values {
            media.unregisterEffect(alertsEffect)
        }
        alertsEffects.removeAll()
        for widget in widgets where widget.type == .alerts {
            alertsEffects[widget.id] = AlertsEffect(
                settings: widget.alerts.clone(),
                delegate: self,
                mediaStorage: alertMediaStorage,
                bundledImages: database.alertsMediaGallery.bundledImages,
                bundledSounds: database.alertsMediaGallery.bundledSounds
            )
        }
        for vTuberEffect in vTuberEffects.values {
            media.unregisterEffect(vTuberEffect)
        }
        vTuberEffects.removeAll()
        for widget in widgets where widget.type == .vTuber {
            vTuberEffects[widget.id] = VTuberEffect(
                vrm: vTuberStorage.makePath(id: widget.vTuber.id),
                cameraFieldOfView: widget.vTuber.cameraFieldOfView,
                cameraPositionY: widget.vTuber.cameraPositionY
            )
        }
        for pngTuberEffect in pngTuberEffects.values {
            media.unregisterEffect(pngTuberEffect)
        }
        pngTuberEffects.removeAll()
        for widget in widgets where widget.type == .pngTuber {
            pngTuberEffects[widget.id] = PngTuberEffect(
                model: pngTuberStorage.makePath(id: widget.pngTuber.id),
                costume: 1
            )
        }
        browsers = browserEffects.map { _, browser in
            Browser(browserEffect: browser)
        }
    }

    private func isGlobalButtonOn(type: SettingsQuickButtonType) -> Bool {
        return database.quickButtons.first(where: { button in
            button.type == type
        })?.isOn ?? false
    }

    private func isFaceEnabled() -> Bool {
        let settings = database.debug.beautyFilterSettings
        return database.debug.beautyFilter || settings.showBlur || settings.showBlurBackground || settings
            .showMoblin || settings.showBeauty
    }

    func isFixedHorizonEnabled(scene: SettingsScene) -> Bool {
        return database.fixedHorizon && scene.cameraPosition.isBuiltin()
    }

    func resetSelectedScene(changeScene: Bool = true) {
        if !enabledScenes.isEmpty, changeScene {
            setSceneId(id: enabledScenes[0].id)
            sceneIndex = 0
        }
        resetVideoEffects(widgets: getLocalAndRemoteWidgets())
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getVideoSize(),
            size: drawOnStreamSize,
            lines: drawOnStreamLines,
            mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        for lutEffect in lutEffects.values {
            media.unregisterEffect(lutEffect)
        }
        lutEffects.removeAll()
        for lut in allLuts() {
            let lutEffect = LutEffect()
            lutEffect.setLut(lut: lut.clone(), imageStorage: imageStorage) { title, subTitle in
                self.makeErrorToastMain(title: title, subTitle: subTitle)
            }
            lutEffects[lut.id] = lutEffect
        }
        sceneUpdated(imageEffectChanged: true, attachCamera: true)
    }

    private func setSceneId(id: UUID) {
        selectedSceneId = id
        remoteControlStreamer?.stateChanged(state: RemoteControlState(scene: id))
        if isWatchLocal() {
            sendSceneToWatch(id: selectedSceneId)
            sendZoomPresetsToWatch()
            sendZoomPresetToWatch()
        }
        showMediaPlayerControls = enabledScenes.first(where: { $0.id == id })?.cameraPosition == .mediaPlayer
    }

    func getSelectedScene() -> SettingsScene? {
        return findEnabledScene(id: selectedSceneId)
    }

    func showSceneSettings(scene: SettingsScene) {
        sceneSettingsPanelScene = scene
        sceneSettingsPanelSceneId += 1
        toggleShowingPanel(type: nil, panel: .none)
        toggleShowingPanel(type: nil, panel: .sceneSettings)
    }

    func selectSceneByName(name: String) {
        if let scene = enabledScenes.first(where: { $0.name.lowercased() == name.lowercased() }) {
            selectScene(id: scene.id)
        }
    }

    func selectScene(id: UUID) {
        guard id != selectedSceneId else {
            return
        }
        if let index = enabledScenes.firstIndex(where: { scene in
            scene.id == id
        }) {
            sceneIndex = index
            setSceneId(id: id)
            sceneUpdated(attachCamera: true, updateRemoteScene: false)
        }
    }

    func toggleWidgetOnOff(id: UUID) {
        guard let widget = findWidget(id: id) else {
            return
        }
        widget.enabled.toggle()
        reloadSpeechToText()
        sceneUpdated()
    }

    func sceneUpdated(imageEffectChanged: Bool = false, attachCamera: Bool = false, updateRemoteScene: Bool = true) {
        if imageEffectChanged {
            reloadImageEffects()
        }
        guard let scene = getSelectedScene() else {
            sceneUpdatedOff()
            return
        }
        for browserEffect in browserEffects.values {
            browserEffect.stop()
        }
        sceneUpdatedOn(scene: scene, attachCamera: attachCamera)
        startWeatherManager()
        startGeographyManager()
        startGForceManager()
        if updateRemoteScene {
            remoteSceneSettingsUpdated()
        }
    }

    func getSceneName(id: UUID) -> String {
        return database.scenes.first { scene in
            scene.id == id
        }?.name ?? "Unknown"
    }

    private func sceneUpdatedOff() {
        unregisterGlobalVideoEffects()
        for imageEffect in imageEffects.values {
            media.unregisterEffect(imageEffect)
        }
        for textEffect in textEffects.values {
            media.unregisterEffect(textEffect)
        }
        for browserEffect in browserEffects.values {
            media.unregisterEffect(browserEffect)
            browserEffect.stop()
        }
        for mapEffect in mapEffects.values {
            media.unregisterEffect(mapEffect)
        }
        media.unregisterEffect(drawOnStreamEffect)
        media.unregisterEffect(lutEffect)
        for lutEffect in lutEffects.values {
            media.unregisterEffect(lutEffect)
        }
        for padelScoreboardEffect in padelScoreboardEffects.values {
            media.unregisterEffect(padelScoreboardEffect)
        }
    }

    private func findSceneWidget(scene: SettingsScene, widgetId: UUID) -> SettingsSceneWidget? {
        return scene.widgets.first(where: { $0.widgetId == widgetId })
    }

    private func sceneUpdatedOn(scene: SettingsScene, attachCamera: Bool) {
        var effects: [VideoEffect] = []
        if database.color.lutEnabled, database.color.space == .appleLog {
            effects.append(lutEffect)
        }
        for lut in allLuts() {
            guard lut.enabled! else {
                continue
            }
            guard let lutEffect = lutEffects[lut.id] else {
                continue
            }
            effects.append(lutEffect)
        }
        effects += registerGlobalVideoEffects(scene: scene)
        var usedBrowserEffects: [BrowserEffect] = []
        var usedMapEffects: [MapEffect] = []
        var usedPadelScoreboardEffects: [PadelScoreboardEffect] = []
        var addedScenes: [SettingsScene] = []
        var needsSpeechToText = false
        enabledAlertsEffects = []
        var scene = scene
        if let remoteSceneWidget = remoteSceneWidgets.first {
            scene = scene.clone()
            scene.widgets.append(SettingsSceneWidget(widgetId: remoteSceneWidget.id))
        }
        addSceneEffects(
            scene,
            &effects,
            &usedBrowserEffects,
            &usedMapEffects,
            &usedPadelScoreboardEffects,
            &addedScenes,
            &enabledAlertsEffects,
            &needsSpeechToText
        )
        if !drawOnStreamLines.isEmpty {
            effects.append(drawOnStreamEffect)
        }
        effects += registerGlobalVideoEffectsOnTop()
        media.setPendingAfterAttachEffects(effects: effects, rotation: scene.videoSourceRotation)
        for browserEffect in browserEffects.values where !usedBrowserEffects.contains(browserEffect) {
            browserEffect.setSceneWidget(sceneWidget: nil, crops: [])
        }
        for mapEffect in mapEffects.values where !usedMapEffects.contains(mapEffect) {
            mapEffect.setSceneWidget(sceneWidget: nil)
        }
        for (id, padelScoreboardEffect) in padelScoreboardEffects
            where !usedPadelScoreboardEffects.contains(padelScoreboardEffect)
        {
            if isWatchLocal() {
                sendRemovePadelScoreboardToWatch(id: id)
            }
        }
        media.setSpeechToText(enabled: needsSpeechToText)
        if attachCamera {
            attachSingleLayout(scene: scene)
        } else {
            media.usePendingAfterAttachEffects()
        }
        // To do: Should update on first frame in draw effect instead.
        if !drawOnStreamLines.isEmpty {
            drawOnStreamEffect.updateOverlay(
                videoSize: media.getVideoSize(),
                size: drawOnStreamSize,
                lines: drawOnStreamLines,
                mirror: isFrontCameraSelected && !database.mirrorFrontCameraOnStream
            )
        }
    }

    private func addSceneEffects(
        _ scene: SettingsScene,
        _ effects: inout [VideoEffect],
        _ usedBrowserEffects: inout [BrowserEffect],
        _ usedMapEffects: inout [MapEffect],
        _ usedPadelScoreboardEffects: inout [PadelScoreboardEffect],
        _ addedScenes: inout [SettingsScene],
        _ enabledAlertsEffects: inout [AlertsEffect],
        _ needsSpeechToText: inout Bool
    ) {
        guard !addedScenes.contains(scene) else {
            return
        }
        addedScenes.append(scene)
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard widget.enabled else {
                continue
            }
            switch widget.type {
            case .image:
                if let imageEffect = imageEffects[widget.id] {
                    imageEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    effects.append(imageEffect)
                }
            case .text:
                if let textEffect = textEffects[widget.id] {
                    textEffect.setPosition(x: sceneWidget.x, y: sceneWidget.y)
                    effects.append(textEffect)
                    if widget.text.needsSubtitles {
                        needsSpeechToText = true
                    }
                }
            case .videoEffect:
                break
            case .browser:
                if let browserEffect = browserEffects[widget.id], !usedBrowserEffects.contains(browserEffect) {
                    browserEffect.setSceneWidget(
                        sceneWidget: sceneWidget,
                        crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.id)
                    )
                    if !browserEffect.audioOnly {
                        effects.append(browserEffect)
                    }
                    usedBrowserEffects.append(browserEffect)
                }
            case .crop:
                if let browserEffect = browserEffects[widget.crop.sourceWidgetId],
                   !usedBrowserEffects.contains(browserEffect)
                {
                    browserEffect.setSceneWidget(
                        sceneWidget: findSceneWidget(scene: scene, widgetId: widget.crop.sourceWidgetId),
                        crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.crop.sourceWidgetId)
                    )
                    if !browserEffect.audioOnly {
                        effects.append(browserEffect)
                    }
                    usedBrowserEffects.append(browserEffect)
                }
            case .map:
                if let mapEffect = mapEffects[widget.id], !usedMapEffects.contains(mapEffect) {
                    mapEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    effects.append(mapEffect)
                    usedMapEffects.append(mapEffect)
                }
            case .scene:
                if let sceneWidgetScene = getLocalAndRemoteScenes().first(where: { $0.id == widget.scene.sceneId }) {
                    addSceneEffects(
                        sceneWidgetScene,
                        &effects,
                        &usedBrowserEffects,
                        &usedMapEffects,
                        &usedPadelScoreboardEffects,
                        &addedScenes,
                        &enabledAlertsEffects,
                        &needsSpeechToText
                    )
                }
            case .qrCode:
                if let qrCodeEffect = qrCodeEffects[widget.id] {
                    qrCodeEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    effects.append(qrCodeEffect)
                }
            case .alerts:
                if let alertsEffect = alertsEffects[widget.id] {
                    if alertsEffect.shouldRegisterEffect() {
                        effects.append(alertsEffect)
                    }
                    alertsEffect.setPosition(x: sceneWidget.x, y: sceneWidget.y)
                    enabledAlertsEffects.append(alertsEffect)
                    if widget.alerts.needsSubtitles! {
                        needsSpeechToText = true
                    }
                }
            case .videoSource:
                if let videoSourceEffect = videoSourceEffects[widget.id] {
                    if let videoSourceId = getVideoSourceId(cameraId: widget.videoSource.toCameraId()) {
                        videoSourceEffect.setVideoSourceId(videoSourceId: videoSourceId)
                    }
                    videoSourceEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    videoSourceEffect.setSettings(settings: widget.videoSource.toEffectSettings())
                    effects.append(videoSourceEffect)
                }
            case .scoreboard:
                if let padelScoreboardEffect = padelScoreboardEffects[widget.id] {
                    padelScoreboardEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    let scoreboard = widget.scoreboard
                    padelScoreboardEffect
                        .update(scoreboard: padelScoreboardSettingsToEffect(scoreboard.padel))
                    if isWatchLocal() {
                        sendUpdatePadelScoreboardToWatch(id: widget.id, scoreboard: scoreboard)
                    }
                    effects.append(padelScoreboardEffect)
                    usedPadelScoreboardEffects.append(padelScoreboardEffect)
                }
            case .vTuber:
                if let vTuberEffect = vTuberEffects[widget.id] {
                    if let videoSourceId = getVideoSourceId(cameraId: widget.vTuber.toCameraId()) {
                        vTuberEffect.setVideoSourceId(videoSourceId: videoSourceId)
                    }
                    vTuberEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    vTuberEffect.setSettings(
                        cameraFieldOfView: widget.vTuber.cameraFieldOfView,
                        cameraPositionY: widget.vTuber.cameraPositionY,
                        mirror: widget.vTuber.mirror
                    )
                    effects.append(vTuberEffect)
                }
            case .pngTuber:
                if let pngTuberEffect = pngTuberEffects[widget.id] {
                    if let videoSourceId = getVideoSourceId(cameraId: widget.pngTuber.toCameraId()) {
                        pngTuberEffect.setVideoSourceId(videoSourceId: videoSourceId)
                    }
                    pngTuberEffect.setSceneWidget(sceneWidget: sceneWidget.clone())
                    pngTuberEffect.setSettings(mirror: widget.pngTuber.mirror)
                    effects.append(pngTuberEffect)
                }
            }
        }
    }

    func removeDeadWidgetsFromScenes() {
        for scene in database.scenes {
            scene.widgets = scene.widgets.filter { findWidget(id: $0.widgetId) != nil }
        }
    }

    func remoteSceneSettingsUpdated() {
        remoteSceneSettingsUpdateRequested = true
        updateRemoteSceneSettings()
    }

    private func updateRemoteSceneSettings() {
        guard !remoteSceneSettingsUpdating else {
            return
        }
        remoteSceneSettingsUpdating = true
        remoteControlAssistantSetRemoteSceneSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.remoteSceneSettingsUpdating = false
            if self.remoteSceneSettingsUpdateRequested {
                self.remoteSceneSettingsUpdateRequested = false
                self.updateRemoteSceneSettings()
            }
        }
    }

    private func getLocalAndRemoteScenes() -> [SettingsScene] {
        return database.scenes + remoteSceneScenes
    }

    private func getLocalAndRemoteWidgets() -> [SettingsWidget] {
        return database.widgets + remoteSceneWidgets
    }

    func attachSingleLayout(scene: SettingsScene) {
        isFrontCameraSelected = false
        deactivateAllMediaPlayers()
        switch scene.cameraPosition {
        case .back:
            attachCamera(scene: scene, position: .back)
        case .front:
            attachCamera(scene: scene, position: .front)
            isFrontCameraSelected = true
        case .rtmp:
            attachBufferedCamera(cameraId: scene.rtmpCameraId, scene: scene)
        case .srtla:
            attachBufferedCamera(cameraId: scene.srtlaCameraId, scene: scene)
        case .mediaPlayer:
            mediaPlayers[scene.mediaPlayerCameraId]?.activate()
            attachBufferedCamera(cameraId: scene.mediaPlayerCameraId, scene: scene)
        case .external:
            attachExternalCamera(scene: scene)
        case .screenCapture:
            attachBufferedCamera(cameraId: screenCaptureCameraId, scene: scene)
        case .backTripleLowEnergy:
            attachBackTripleLowEnergyCamera()
        case .backDualLowEnergy:
            attachBackDualLowEnergyCamera()
        case .backWideDualLowEnergy:
            attachBackWideDualLowEnergyCamera()
        }
    }

    private func findWidgetCrops(scene: SettingsScene, sourceWidgetId: UUID) -> [WidgetCrop] {
        var crops: [WidgetCrop] = []
        for sceneWidget in scene.widgets.filter({ $0.enabled }) {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                logger.error("Widget not found")
                continue
            }
            guard widget.type == .crop else {
                continue
            }
            let crop = widget.crop
            guard crop.sourceWidgetId == sourceWidgetId else {
                continue
            }
            crops.append(WidgetCrop(position: .init(x: sceneWidget.x, y: sceneWidget.y),
                                    crop: .init(
                                        x: crop.x,
                                        y: crop.y,
                                        width: crop.width,
                                        height: crop.height
                                    )))
        }
        return crops
    }

    func findWidget(id: UUID) -> SettingsWidget? {
        for widget in getLocalAndRemoteWidgets() where widget.id == id {
            return widget
        }
        return nil
    }

    func findEnabledScene(id: UUID) -> SettingsScene? {
        for scene in enabledScenes where id == scene.id {
            return scene
        }
        return nil
    }

    func isCaptureDeviceWidget(widget: SettingsWidget) -> Bool {
        switch widget.type {
        case .scene:
            if let scene = database.scenes.first(where: { $0.id == widget.scene.sceneId }) {
                for widget in getSceneWidgets(scene: scene, onlyEnabled: false) where
                    isCaptureDeviceWidget(widget: widget)
                {
                    return true
                }
            }
            return false
        case .videoSource:
            switch widget.videoSource.cameraPosition {
            case .back:
                return true
            case .backWideDualLowEnergy:
                return true
            case .backDualLowEnergy:
                return true
            case .backTripleLowEnergy:
                return true
            case .front:
                return true
            case .external:
                return true
            default:
                return false
            }
        case .vTuber:
            switch widget.vTuber.cameraPosition {
            case .back:
                return true
            case .backWideDualLowEnergy:
                return true
            case .backDualLowEnergy:
                return true
            case .backTripleLowEnergy:
                return true
            case .front:
                return true
            case .external:
                return true
            default:
                return false
            }
        case .pngTuber:
            switch widget.pngTuber.cameraPosition {
            case .back:
                return true
            case .backWideDualLowEnergy:
                return true
            case .backDualLowEnergy:
                return true
            case .backTripleLowEnergy:
                return true
            case .front:
                return true
            case .external:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    func getFillFrame(scene: SettingsScene) -> Bool {
        return scene.fillFrame
    }

    func widgetsInCurrentScene(onlyEnabled: Bool) -> [SettingsWidget] {
        guard let scene = getSelectedScene() else {
            return []
        }
        var found: [UUID] = []
        return getSceneWidgets(scene: scene, onlyEnabled: onlyEnabled).filter {
            if found.contains($0.id) {
                return false
            } else {
                found.append($0.id)
                return true
            }
        }
    }

    private func getSceneWidgets(scene: SettingsScene, onlyEnabled: Bool) -> [SettingsWidget] {
        var widgets: [SettingsWidget] = []
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard !onlyEnabled || widget.enabled else {
                continue
            }
            widgets.append(widget)
            guard widget.type == .scene else {
                continue
            }
            if let scene = database.scenes.first(where: { $0.id == widget.scene.sceneId }) {
                widgets += getSceneWidgets(scene: scene, onlyEnabled: onlyEnabled)
            }
        }
        return widgets
    }

    private func updateTextWidgetsLapTimes(now: Date) {
        for widget in database.widgets where widget.type == .text {
            guard !widget.text.lapTimes.isEmpty else {
                continue
            }
            let now = now.timeIntervalSince1970
            for lapTimes in widget.text.lapTimes {
                let lastIndex = lapTimes.lapTimes.endIndex - 1
                guard lastIndex >= 0, let currentLapStartTime = lapTimes.currentLapStartTime else {
                    continue
                }
                lapTimes.lapTimes[lastIndex] = now - currentLapStartTime
            }
            getTextEffect(id: widget.id)?.setLapTimes(lapTimes: widget.text.lapTimes.map { $0.lapTimes })
        }
    }

    func updateTextEffects(now: Date, timestamp: ContinuousClock.Instant) {
        guard !textEffects.isEmpty else {
            return
        }
        var stats: TextEffectStats
        if let textStats = remoteSceneData.textStats {
            stats = textStats.toStats()
        } else {
            updateTextWidgetsLapTimes(now: now)
            let location = locationManager.getLatestKnownLocation()
            let weather = weatherManager.getLatestWeather()
            let placemark = geographyManager.getLatestPlacemark()
            stats = TextEffectStats(
                timestamp: timestamp,
                bitrateAndTotal: speedAndTotal,
                date: now,
                debugOverlayLines: debugOverlay.debugLines,
                speed: format(speed: location?.speed ?? 0),
                averageSpeed: format(speed: averageSpeed),
                altitude: format(altitude: location?.altitude ?? 0),
                distance: getDistance(),
                slope: "\(Int(slopePercent)) %",
                conditions: weather?.currentWeather.symbolName,
                temperature: weather?.currentWeather.temperature,
                country: placemark?.country ?? "",
                countryFlag: emojiFlag(country: placemark?.isoCountryCode ?? ""),
                city: placemark?.locality,
                muted: isMuteOn,
                heartRates: heartRates,
                activeEnergyBurned: workoutActiveEnergyBurned,
                workoutDistance: workoutDistance,
                power: workoutPower,
                stepCount: workoutStepCount,
                teslaBatteryLevel: textEffectTeslaBatteryLevel(),
                teslaDrive: textEffectTeslaDrive(),
                teslaMedia: textEffectTeslaMedia(),
                cyclingPower: "\(cyclingPower) W",
                cyclingCadence: "\(cyclingCadence)",
                browserTitle: getBrowserTitle(),
                gForce: gForceManager?.getLatest()
            )
            remoteControlAssistantSetRemoteSceneDataTextStats(stats: stats)
        }
        for textEffect in textEffects.values {
            textEffect.updateStats(stats: stats)
        }
    }

    private func getBrowserTitle() -> String {
        if showBrowser {
            return getWebBrowser().title ?? ""
        } else {
            return ""
        }
    }

    func forceUpdateTextEffects() {
        for textEffect in textEffects.values {
            textEffect.forceImageUpdate()
        }
    }

    func updateMapEffects() {
        guard !mapEffects.isEmpty else {
            return
        }
        let location: CLLocation
        if let remoteSceneLocation = remoteSceneData.location {
            location = remoteSceneLocation.toLocation()
        } else {
            guard var latestKnownLocation = locationManager.getLatestKnownLocation() else {
                return
            }
            if isLocationInPrivacyRegion(location: latestKnownLocation) {
                latestKnownLocation = .init()
            }
            remoteControlAssistantSetRemoteSceneDataLocation(location: latestKnownLocation)
            location = latestKnownLocation
        }
        for mapEffect in mapEffects.values {
            mapEffect.updateLocation(location: location)
        }
    }

    func isSceneVideoSourceActive(scene: SettingsScene) -> Bool {
        switch scene.cameraPosition {
        case .rtmp:
            if let stream = getRtmpStream(id: scene.rtmpCameraId) {
                return isRtmpStreamConnected(streamKey: stream.streamKey)
            } else {
                return false
            }
        case .srtla:
            if let stream = getSrtlaStream(id: scene.srtlaCameraId) {
                return isSrtlaStreamConnected(streamId: stream.streamId)
            } else {
                return false
            }
        case .external:
            return isExternalCameraConnected(id: scene.externalCameraId)
        default:
            return true
        }
    }

    func isSceneVideoSourceActive(sceneId: UUID) -> Bool {
        guard let scene = enabledScenes.first(where: { $0.id == sceneId }) else {
            return false
        }
        return isSceneVideoSourceActive(scene: scene)
    }

    func getBuiltinCameraDevices(scene: SettingsScene, sceneDevice: AVCaptureDevice?) -> CaptureDevices {
        var devices = CaptureDevices(hasSceneDevice: false, devices: [])
        if let sceneDevice {
            devices.hasSceneDevice = true
            devices.devices.append(makeCaptureDevice(device: sceneDevice))
        }
        getBuiltinCameraDevicesInScene(scene: scene, devices: &devices.devices)
        return devices
    }

    private func getBuiltinCameraDevicesInScene(scene: SettingsScene, devices: inout [CaptureDevice]) {
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard widget.enabled else {
                continue
            }
            switch widget.type {
            case .videoSource:
                getBuiltinCameraDevicesForVideoSourceWidget(videoSource: widget.videoSource, devices: &devices)
            case .vTuber:
                getBuiltinCameraDevicesForVTuberWidget(vTuber: widget.vTuber, devices: &devices)
            case .pngTuber:
                getBuiltinCameraDevicesForPngTuberWidget(pngTuber: widget.pngTuber, devices: &devices)
            case .scene:
                getBuiltinCameraDevicesForSceneWidget(scene: widget.scene, devices: &devices)
            default:
                break
            }
        }
    }

    private func getBuiltinCameraDevicesForVideoSourceWidget(
        videoSource: SettingsWidgetVideoSource,
        devices: inout [CaptureDevice]
    ) {
        let cameraId: String?
        switch videoSource.cameraPosition {
        case .back:
            cameraId = videoSource.backCameraId
        case .front:
            cameraId = videoSource.frontCameraId
        case .external:
            cameraId = videoSource.externalCameraId
        default:
            cameraId = nil
        }
        if let cameraId, let device = AVCaptureDevice(uniqueID: cameraId) {
            if !devices.contains(where: { $0.device == device }) {
                devices.append(makeCaptureDevice(device: device))
            }
        }
    }

    private func getBuiltinCameraDevicesForVTuberWidget(vTuber: SettingsWidgetVTuber, devices: inout [CaptureDevice]) {
        let cameraId: String?
        switch vTuber.cameraPosition {
        case .back:
            cameraId = vTuber.backCameraId
        case .front:
            cameraId = vTuber.frontCameraId
        case .external:
            cameraId = vTuber.externalCameraId
        default:
            cameraId = nil
        }
        if let cameraId, let device = AVCaptureDevice(uniqueID: cameraId) {
            if !devices.contains(where: { $0.device == device }) {
                devices.append(makeCaptureDevice(device: device))
            }
        }
    }

    private func getBuiltinCameraDevicesForPngTuberWidget(
        pngTuber: SettingsWidgetPngTuber,
        devices: inout [CaptureDevice]
    ) {
        let cameraId: String?
        switch pngTuber.cameraPosition {
        case .back:
            cameraId = pngTuber.backCameraId
        case .front:
            cameraId = pngTuber.frontCameraId
        case .external:
            cameraId = pngTuber.externalCameraId
        default:
            cameraId = nil
        }
        if let cameraId, let device = AVCaptureDevice(uniqueID: cameraId) {
            if !devices.contains(where: { $0.device == device }) {
                devices.append(makeCaptureDevice(device: device))
            }
        }
    }

    private func getBuiltinCameraDevicesForSceneWidget(scene: SettingsWidgetScene, devices: inout [CaptureDevice]) {
        if let scene = database.scenes.first(where: { $0.id == scene.sceneId }) {
            getBuiltinCameraDevicesInScene(scene: scene, devices: &devices)
        }
    }

    func switchToNextSceneRoundRobin() {
        guard let currentSceneIndex = enabledScenes.firstIndex(where: { $0.id == selectedSceneId }) else {
            return
        }
        let nextSceneIndex = (currentSceneIndex + 1) % enabledScenes.count
        guard nextSceneIndex != currentSceneIndex else {
            return
        }
        selectScene(id: enabledScenes[nextSceneIndex].id)
    }
}
