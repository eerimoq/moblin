import AVFoundation
import CoreLocation
import SwiftUI

class CreateWidgetWizard: ObservableObject {
    @Published var name: String = ""
    @Published var type: SettingsWidgetType = .text
    var widget: SettingsWidget = .init(name: "")

    func reset() {
        name = ""
        type = .text
        widget = .init(name: "")
        widget.text.formatString = ""
        let yes = SettingsWidgetWheelOfLuckOption()
        yes.text = String(localized: "Yes")
        let no = SettingsWidgetWheelOfLuckOption()
        no.text = String(localized: "No")
        let later = SettingsWidgetWheelOfLuckOption()
        later.text = String(localized: "Later")
        let spinAgain = SettingsWidgetWheelOfLuckOption()
        spinAgain.text = String(localized: "Spin again")
        widget.wheelOfLuck.options = [yes, no, later, spinAgain]
        widget.wheelOfLuck.updateText()
        widget.wheelOfLuck.updateTotalWeight()
    }
}

struct WidgetInScene: Identifiable {
    var id: UUID {
        widget.id
    }

    let widget: SettingsWidget
    let sceneWidget: SettingsSceneWidget
}

extension Model {
    func getTextEffects(id: UUID) -> [TextEffect] {
        var effects: [TextEffect] = []
        if let effect = textEffects.first(where: { $0.key == id })?.value {
            effects.append(effect)
        }
        for slideshow in slideshowEffects.values {
            for slide in slideshow.slides where slide.widgetId == id {
                if let textEffect = slide.effect as? TextEffect {
                    effects.append(textEffect)
                }
            }
        }
        return effects
    }

    func getVideoSourceEffect(id: UUID) -> VideoSourceEffect? {
        return videoSourceEffects.first(where: { $0.key == id })?.value
    }

    func getVTuberEffect(id: UUID) -> VTuberEffect? {
        return vTuberEffects.first(where: { $0.key == id })?.value
    }

    func getPngTuberEffect(id: UUID) -> PngTuberEffect? {
        return pngTuberEffects.first(where: { $0.key == id })?.value
    }

    func getSnapshotEffect(id: UUID) -> SnapshotEffect? {
        return snapshotEffects.first(where: { $0.key == id })?.value
    }

    func getChatEffect(id: UUID) -> ChatEffect? {
        return chatEffects.first(where: { $0.key == id })?.value
    }

    func getQrCodeEffect(id: UUID) -> QrCodeEffect? {
        return qrCodeEffects.first(where: { $0.key == id })?.value
    }

    func getWheelOfLuckEffect(id: UUID) -> WheelOfLuckEffect? {
        return wheelOfLuckEffects.first(where: { $0.key == id })?.value
    }

    func getBingoCardEffect(id: UUID) -> BingoCardEffect? {
        return bingoCardEffects.first(where: { $0.key == id })?.value
    }

    func getScoreboardEffect(id: UUID) -> ScoreboardEffect? {
        return scoreboardEffects.first(where: { $0.key == id })?.value
    }

    func getWidgetShapeEffect(_ widget: SettingsWidget, _ effect: SettingsVideoEffect) -> ShapeEffect? {
        return getWidgetVideoEffect(widget, effect)
    }

    func getWidgetAnamorphicLensEffect(_ widget: SettingsWidget,
                                       _ effect: SettingsVideoEffect) -> AnamorphicLensEffect?
    {
        return getWidgetVideoEffect(widget, effect)
    }

    func getWidgetDewarp360Effect(_ widget: SettingsWidget,
                                  _ effect: SettingsVideoEffect) -> Dewarp360Effect?
    {
        return getWidgetVideoEffect(widget, effect)
    }

    func getWidgetLutEffect(_ widget: SettingsWidget, _ effect: SettingsVideoEffect) -> LutEffect? {
        return getWidgetVideoEffect(widget, effect)
    }

    func getWidgetRemoveBackgroundEffect(_ widget: SettingsWidget,
                                         _ effect: SettingsVideoEffect) -> RemoveBackgroundEffect?
    {
        return getWidgetVideoEffect(widget, effect)
    }

    private func getEffectWithPossibleEffects(id: UUID) -> VideoEffect? {
        return getVideoSourceEffect(id: id)
            ?? getImageEffect(id: id)
            ?? getBrowserEffect(id: id)
            ?? getMapEffect(id: id)
            ?? getSnapshotEffect(id: id)
            ?? getQrCodeEffect(id: id)
    }

    private func getWidgetVideoEffect<T>(_ widget: SettingsWidget, _ effect: SettingsVideoEffect) -> T? {
        guard let effectIndex = widget.effects.filter({ $0.enabled }).firstIndex(where: { $0 === effect }),
              let effect = getEffectWithPossibleEffects(id: widget.id),
              effectIndex < effect.effects.count
        else {
            return nil
        }
        return effect.effects[effectIndex] as? T
    }

    func isFixedHorizonEnabled(scene: SettingsScene) -> Bool {
        return database.fixedHorizon && scene.videoSource.cameraPosition.isBuiltin()
    }

    func resetSelectedScene(changeScene: Bool = true, attachCamera: Bool = true) {
        if !enabledScenes.isEmpty, changeScene {
            setSceneId(id: enabledScenes[0].id)
            sceneSelector.sceneIndex = 0
        }
        resetVideoEffects(widgets: getLocalAndRemoteWidgets())
        drawOnStreamEffect.updateOverlay(
            videoSize: media.getCanvasSize(),
            size: drawOnStreamSize,
            lines: drawOnStream.lines,
            mirror: streamOverlay.isFrontCameraSelected && !database.mirrorFrontCameraOnStream
        )
        lutEffects.removeAll()
        for lut in allLuts() {
            let lutEffect = LutEffect()
            lutEffect.setLut(lut: lut.clone(), imageStorage: imageStorage) { title, subTitle in
                self.makeErrorToastMain(title: title, subTitle: subTitle)
            }
            lutEffects[lut.id] = lutEffect
        }
        sceneUpdated(attachCamera: attachCamera)
    }

    func getSelectedScene() -> SettingsScene? {
        return findEnabledScene(id: sceneSelector.selectedSceneId)
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
        guard id != sceneSelector.selectedSceneId else {
            return
        }
        if let index = findEnabledSceneIndex(id: id) {
            sceneSelector.sceneIndex = index
            setSceneId(id: id)
            sceneUpdated(attachCamera: true, updateRemoteScene: false)
            switchMicIfNeededAfterSceneSwitch()
        }
    }

    func toggleWidgetOnOff(id: UUID) {
        guard let widget = findWidget(id: id) else {
            return
        }
        widget.enabled.toggle()
        sceneUpdated()
    }

    func sceneUpdated(attachCamera: Bool = false, updateRemoteScene: Bool = true) {
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
        updateStatusCameraText()
        updateSpeechToText()
    }

    func getSceneName(id: UUID?) -> String? {
        return database.scenes.first { $0.id == id }?.name
    }

    func getWidgetName(id: UUID?) -> String? {
        return database.widgets.first { $0.id == id }?.name
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

    func attachSingleLayout(scene: SettingsScene) {
        streamOverlay.isFrontCameraSelected = false
        deactivateAllMediaPlayers()
        switch scene.videoSource.cameraPosition {
        case .back:
            attachCamera(scene: scene, position: .back)
        case .front:
            attachCamera(scene: scene, position: .front)
            streamOverlay.isFrontCameraSelected = true
        case .rtmp:
            attachBufferedCamera(cameraId: scene.videoSource.rtmpCameraId, scene: scene)
        case .srtla:
            attachBufferedCamera(cameraId: scene.videoSource.srtlaCameraId, scene: scene)
        case .rist:
            attachBufferedCamera(cameraId: scene.videoSource.ristCameraId, scene: scene)
        case .rtsp:
            attachBufferedCamera(cameraId: scene.videoSource.rtspCameraId, scene: scene)
        case .mediaPlayer:
            mediaPlayers[scene.videoSource.mediaPlayerCameraId]?.activate()
            attachBufferedCamera(cameraId: scene.videoSource.mediaPlayerCameraId, scene: scene)
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
        case .none:
            attachBufferedCamera(cameraId: noneCameraId, scene: scene)
        }
    }

    func findWidget(id: UUID) -> SettingsWidget? {
        for widget in getLocalAndRemoteWidgets() where widget.id == id {
            return widget
        }
        return nil
    }

    func findWidget(name: String) -> SettingsWidget? {
        for widget in getLocalAndRemoteWidgets() where widget.name == name {
            return widget
        }
        return nil
    }

    func getTextWidget(id: UUID?) -> SettingsWidget? {
        guard let id else {
            return nil
        }
        if let widget = findWidget(id: id), widget.type == .text {
            return widget
        }
        return nil
    }

    func findEnabledScene(id: UUID) -> SettingsScene? {
        return enabledScenes.first(where: { $0.id == id })
    }

    func findEnabledSceneIndex(id: UUID) -> Int? {
        return enabledScenes.firstIndex(where: { $0.id == id })
    }

    func isCaptureDeviceWidget(widget: SettingsWidget) -> Bool {
        var addedSceneIds: Set<UUID> = []
        return isCaptureDeviceWidgetInternal(widget: widget, addedSceneIds: &addedSceneIds)
    }

    func getFillFrame(scene: SettingsScene) -> Bool {
        return scene.fillFrame
    }

    func widgetsInCurrentScene(onlyEnabled: Bool) -> [WidgetInScene] {
        guard let scene = getSelectedScene() else {
            return []
        }
        var found: [UUID] = []
        return getSceneWidgets(scene: scene, onlyEnabled: onlyEnabled).filter {
            if found.contains($0.widget.id) {
                return false
            } else {
                found.append($0.widget.id)
                return true
            }
        }
    }

    func getSceneWidgets(scene: SettingsScene, onlyEnabled: Bool) -> [WidgetInScene] {
        var addedSceneIds: Set<UUID> = []
        return getSceneWidgetsInternal(scene, onlyEnabled, &addedSceneIds)
    }

    func switchToNextSceneRoundRobin() {
        guard let currentSceneIndex = findEnabledSceneIndex(id: sceneSelector.selectedSceneId) else {
            return
        }
        let nextSceneIndex = (currentSceneIndex + 1) % enabledScenes.count
        guard nextSceneIndex != currentSceneIndex else {
            return
        }
        selectScene(id: enabledScenes[nextSceneIndex].id)
    }

    func appendWidgetToScene(scene: SettingsScene, widget: SettingsWidget) {
        scene.widgets.append(createSceneWidget(widget: widget))
        var attachCamera = false
        if scene.id == getSelectedScene()?.id {
            attachCamera = isCaptureDeviceWidget(widget: widget)
        }
        sceneUpdated(attachCamera: attachCamera)
    }

    func textWidgetTextChanged(widget: SettingsWidget) {
        let parts = loadTextFormat(format: widget.text.formatString)
        for effect in getTextEffects(id: widget.id) {
            effect.setFormat(format: widget.text.formatString)
            updateTimers(widget.text, effect, parts)
            updateStopwatches(widget.text, effect, parts)
            updateCheckboxes(widget.text, effect, parts)
            updateRatings(widget.text, effect, parts)
            updateLapTimes(widget.text, effect, parts)
            updateSubtitles(widget.text, effect, parts)
        }
        updateNeedsWeather(widget.text, parts)
        updateNeedsGeography(widget.text, parts)
        updateNeedsGForce(widget.text, parts)
        sceneUpdated()
    }

    func updateSettingsFromTextWidgets() {
        for widgetId in textEffects.keys {
            guard let widget = findWidget(id: widgetId) else {
                continue
            }
            for stopwatch in widget.text.stopwatches where stopwatch.running {
                stopwatch.totalElapsed += stopwatch.playPressedTime.duration(to: .now).seconds
            }
        }
    }

    func loadTextWidgetStopwatches() {
        for widget in database.widgets where widget.type == .text {
            for stopwatch in widget.text.stopwatches where stopwatch.running {
                stopwatch.playPressedTime = .now
            }
        }
    }

    func forceUpdateTextEffects() {
        for effect in textEffects.values {
            effect.forceOverlayUpdate()
        }
        for effect in slideshowEffects.values {
            for slide in effect.slides {
                if let textEffect = slide.effect as? TextEffect {
                    textEffect.forceOverlayUpdate()
                }
            }
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
        switch scene.videoSource.cameraPosition {
        case .rtmp:
            return activeBufferedVideoIds.contains(scene.videoSource.rtmpCameraId)
        case .srtla:
            return activeBufferedVideoIds.contains(scene.videoSource.srtlaCameraId)
        case .rist:
            return activeBufferedVideoIds.contains(scene.videoSource.ristCameraId)
        case .rtsp:
            return activeBufferedVideoIds.contains(scene.videoSource.rtspCameraId)
        case .external:
            return isExternalCameraConnected(id: scene.videoSource.externalCameraId)
        default:
            return true
        }
    }

    func isCurrentScenesVideoSourceNetwork(cameraId: UUID) -> Bool {
        guard let scene = getSelectedScene() else {
            return false
        }
        return scene.videoSource.isNetwork(cameraId: cameraId)
    }

    func isSceneVideoSourceActive(sceneId: UUID) -> Bool {
        guard let scene = findEnabledScene(id: sceneId) else {
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
        var addedSceneIds: Set<UUID> = []
        if let quickSwitchGroup = scene.quickSwitchGroup {
            for otherScene in enabledScenes where otherScene.quickSwitchGroup == quickSwitchGroup {
                getBuiltinCameraDevices(videoSource: otherScene.videoSource, devices: &devices.devices)
                getBuiltinCameraDevicesInScene(scene: otherScene,
                                               devices: &devices.devices,
                                               addedSceneIds: &addedSceneIds)
            }
        }
        getBuiltinCameraDevicesInScene(scene: scene,
                                       devices: &devices.devices,
                                       addedSceneIds: &addedSceneIds)
        return devices
    }

    private func createGlobalVideoEffects() {
        faceEffect = FaceEffect()
        updateFaceFilterSettings()
        movieEffect = MovieEffect()
        grayScaleEffect = GrayScaleEffect()
        sepiaEffect = SepiaEffect()
        tripleEffect = TripleEffect()
        twinEffect = TwinEffect()
        pixellateEffect = PixellateEffect(strength: database.pixellateStrength)
        pollEffect = nil
        whirlpoolEffect = WhirlpoolEffect(angle: database.whirlpoolAngle)
        pinchEffect = PinchEffect(scale: database.pinchScale)
        fixedHorizonEffect = FixedHorizonEffect()
        glassesEffect = createGlassesEffect()
        sparkleEffect = createStarEffect()
        beautyEffect = BeautyEffect()
        beautyEffect.setSettings(amount: database.beautyStrength, radius: database.beautyRadius)
    }

    private func createGlassesEffect() -> AlertsEffect {
        let settings = SettingsWidgetAlerts()
        settings.disableAll()
        settings.quickButton.enabled = true
        settings.quickButton.positionType = .face
        settings.quickButton.facePosition.x = 0.24
        settings.quickButton.facePosition.y = 0.30
        settings.quickButton.facePosition.width = 0.49
        settings.quickButton.facePosition.height = 0.49
        settings.quickButton.imageId = database.alertsMediaGallery.getGlassesImageId()
        settings.quickButton.imageLoopCount = 3
        return AlertsEffect(settings: settings,
                            delegate: self,
                            mediaStorage: alertMediaStorage,
                            bundledImages: database.alertsMediaGallery.bundledImages,
                            bundledSounds: database.alertsMediaGallery.bundledSounds)
    }

    private func createStarEffect() -> AlertsEffect {
        let settings = SettingsWidgetAlerts()
        settings.disableAll()
        settings.quickButton.enabled = true
        settings.quickButton.positionType = .face
        settings.quickButton.facePosition.x = (alertsEffectBackgroundRightEyeRectangle.topLeftX
            + alertsEffectBackgroundRightEyeRectangle.bottomRightX) / 2 + 0.01
        settings.quickButton.facePosition.y = alertsEffectBackgroundRightEyeRectangle.topLeftY + 0.03
        settings.quickButton.facePosition.width = alertsEffectBackgroundRightEyeRectangle.width() * 0.8
        settings.quickButton.facePosition.height = alertsEffectBackgroundRightEyeRectangle.height() * 0.8
        settings.quickButton.imageId = database.alertsMediaGallery.getWhiteStarImageId()
        return AlertsEffect(settings: settings,
                            delegate: self,
                            mediaStorage: alertMediaStorage,
                            bundledImages: database.alertsMediaGallery.bundledImages,
                            bundledSounds: database.alertsMediaGallery.bundledSounds)
    }

    private func registerGlobalVideoEffects(scene: SettingsScene) -> [VideoEffect] {
        var effects: [VideoEffect] = []
        if let sparkleEffect {
            effects.append(sparkleEffect)
        }
        if let glassesEffect {
            effects.append(glassesEffect)
        }
        let fixedHorizonStatus: String
        if isFixedHorizonEnabled(scene: scene) {
            fixedHorizonEffect.start(portrait: stream.portrait)
            fixedHorizonStatus = "Enabled"
            effects.append(fixedHorizonEffect)
        } else {
            fixedHorizonStatus = "Disabled"
            fixedHorizonEffect.stop()
        }
        if fixedHorizonStatus != statusTopRight.fixedHorizonStatus {
            statusTopRight.fixedHorizonStatus = fixedHorizonStatus
        }
        if isFaceEnabled() {
            effects.append(faceEffect)
        }
        if isQuickButtonOn(type: .whirlpool) {
            effects.append(whirlpoolEffect)
        }
        if isQuickButtonOn(type: .pinch) {
            effects.append(pinchEffect)
        }
        if isQuickButtonOn(type: .movie) {
            effects.append(movieEffect)
        }
        if isQuickButtonOn(type: .fourThree) {
            effects.append(fourThreeEffect)
        }
        if isQuickButtonOn(type: .grayScale) {
            effects.append(grayScaleEffect)
        }
        if isQuickButtonOn(type: .sepia) {
            effects.append(sepiaEffect)
        }
        if isQuickButtonOn(type: .triple) {
            effects.append(tripleEffect)
        }
        if isQuickButtonOn(type: .twin) {
            effects.append(twinEffect)
        }
        if isQuickButtonOn(type: .pixellate) {
            pixellateEffect.setSettings(strength: database.pixellateStrength)
            effects.append(pixellateEffect)
        }
        if isQuickButtonOn(type: .beauty) {
            effects.append(beautyEffect)
        }
        return effects
    }

    private func registerGlobalVideoEffectsOnTop() -> [VideoEffect] {
        var effects: [VideoEffect] = []
        if isQuickButtonOn(type: .poll) {
            if let pollEffect {
                effects.append(pollEffect)
            }
        }
        return effects
    }

    private func getImageEffect(id: UUID) -> ImageEffect? {
        return imageEffects.first(where: { $0.key == id })?.value
    }

    private func getBrowserEffect(id: UUID) -> BrowserEffect? {
        return browserEffects.first(where: { $0.key == id })?.value
    }

    private func getMapEffect(id: UUID) -> MapEffect? {
        return mapEffects.first(where: { $0.key == id })?.value
    }

    private func resetVideoEffects(widgets: [SettingsWidget]) {
        media.unregisterAllEffects()
        createGlobalVideoEffects()
        resetImageEffects(widgets: widgets)
        resetTextVideoEffects(widgets: widgets)
        resetBrowserVideoEffects(widgets: widgets)
        resetMapVideoEffects(widgets: widgets)
        resetQrCodeVideoEffects(widgets: widgets)
        resetVideoSourceVideoEffects(widgets: widgets)
        resetScoreboardVideoEffects(widgets: widgets)
        resetAlertsVideoEffects(widgets: widgets)
        resetVTuberVideoEffects(widgets: widgets)
        resetPngTuberVideoEffects(widgets: widgets)
        resetSnapshotVideoEffects(widgets: widgets)
        resetChatVideoEffects(widgets: widgets)
        resetSlideshowVideoEffects(widgets: widgets)
        resetWheelOfLuckEffects(widgets: widgets)
        resetBingoCardEffects(widgets: widgets)
        browsers = browserEffects.map { _, browser in
            Browser(browserEffect: browser)
        }
    }

    private func createImageEffect(widget: SettingsWidget) -> ImageEffect {
        return ImageEffect(imageStorage: imageStorage, widgetId: widget.id)
    }

    private func resetImageEffects(widgets: [SettingsWidget]) {
        imageEffects.removeAll()
        for widget in widgets where widget.type == .image {
            let effect = createImageEffect(widget: widget)
            effect.effects = widget.getEffects(model: self)
            imageEffects[widget.id] = effect
        }
    }

    private func createTextEffect(widget: SettingsWidget) -> TextEffect {
        return TextEffect(
            format: widget.text.formatString,
            backgroundColor: widget.text.backgroundColor,
            foregroundColor: widget.text.foregroundColor,
            fontSize: CGFloat(widget.text.fontSize),
            fontDesign: widget.text.fontDesign.toSystem(),
            fontWeight: widget.text.fontWeight.toSystem(),
            fontMonospacedDigits: widget.text.fontMonospacedDigits,
            horizontalAlignment: widget.text.horizontalAlignment.toSystem(),
            width: widget.text.widthEnabled ? widget.text.width : nil,
            cornerRadius: Double(widget.text.cornerRadius),
            delay: widget.text.delay,
            timersEndTime: widget.text.timers.map {
                .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
            },
            stopwatches: widget.text.stopwatches.map { $0.clone() },
            checkboxes: widget.text.checkboxes.map { $0.checked },
            ratings: widget.text.ratings.map { $0.rating },
            lapTimes: widget.text.lapTimes.map { $0.lapTimes }
        )
    }

    private func resetTextVideoEffects(widgets: [SettingsWidget]) {
        textEffects.removeAll()
        for widget in widgets where widget.type == .text {
            textEffects[widget.id] = createTextEffect(widget: widget)
        }
    }

    private func resetBrowserVideoEffects(widgets: [SettingsWidget]) {
        for effect in browserEffects.values {
            effect.stop()
        }
        browserEffects.removeAll()
        for widget in widgets where widget.type == .browser {
            guard let url = URL(string: widget.browser.url) else {
                continue
            }
            let effect = BrowserEffect(
                url: url,
                styleSheet: widget.browser.styleSheet,
                widget: widget.browser,
                moblinAccess: widget.browser.moblinAccess
            )
            effect.effects = widget.getEffects(model: self)
            browserEffects[widget.id] = effect
        }
    }

    private func resetMapVideoEffects(widgets: [SettingsWidget]) {
        mapEffects.removeAll()
        for widget in widgets where widget.type == .map {
            let effect = MapEffect(widget: widget.map)
            effect.effects = widget.getEffects(model: self)
            mapEffects[widget.id] = effect
        }
    }

    private func resetQrCodeVideoEffects(widgets: [SettingsWidget]) {
        qrCodeEffects.removeAll()
        for widget in widgets where widget.type == .qrCode {
            let effect = QrCodeEffect(widget: widget.qrCode.clone())
            effect.effects = widget.getEffects(model: self)
            qrCodeEffects[widget.id] = effect
        }
    }

    private func resetVideoSourceVideoEffects(widgets: [SettingsWidget]) {
        videoSourceEffects.removeAll()
        for widget in widgets where widget.type == .videoSource {
            let effect = VideoSourceEffect()
            effect.effects = widget.getEffects(model: self)
            videoSourceEffects[widget.id] = effect
        }
    }

    private func resetScoreboardVideoEffects(widgets: [SettingsWidget]) {
        scoreboardEffects.removeAll()
        for widget in widgets where widget.type == .scoreboard {
            scoreboardEffects[widget.id] = ScoreboardEffect()
        }
    }

    private func resetAlertsVideoEffects(widgets: [SettingsWidget]) {
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
    }

    private func resetVTuberVideoEffects(widgets: [SettingsWidget]) {
        vTuberEffects.removeAll()
        for widget in widgets where widget.type == .vTuber {
            vTuberEffects[widget.id] = VTuberEffect(
                vrm: vTuberStorage.makePath(id: widget.vTuber.id),
                cameraFieldOfView: widget.vTuber.cameraFieldOfView,
                cameraPositionY: widget.vTuber.cameraPositionY
            )
        }
    }

    private func resetPngTuberVideoEffects(widgets: [SettingsWidget]) {
        pngTuberEffects.removeAll()
        for widget in widgets where widget.type == .pngTuber {
            pngTuberEffects[widget.id] = PngTuberEffect(
                model: pngTuberStorage.makePath(id: widget.pngTuber.id),
                costume: 1
            )
        }
    }

    private func resetSnapshotVideoEffects(widgets: [SettingsWidget]) {
        snapshotEffects.removeAll()
        for widget in widgets where widget.type == .snapshot {
            let effect = SnapshotEffect(showtime: widget.snapshot.showtime)
            effect.effects = widget.getEffects(model: self)
            snapshotEffects[widget.id] = effect
        }
    }

    private func resetChatVideoEffects(widgets: [SettingsWidget]) {
        chatEffects.removeAll()
        for widget in widgets where widget.type == .chat {
            let effect = ChatEffect(chat: chatWidgetChat)
            effect.setSettings(settings: widget.chat)
            chatEffects[widget.id] = effect
        }
    }

    private func resetSlideshowVideoEffects(widgets: [SettingsWidget]) {
        slideshowEffects.removeAll()
        for widget in widgets where widget.type == .slideshow {
            var slides: [SlideshowEffectSlide] = []
            for slide in widget.slideshow.slides {
                guard let widgetId = slide.widgetId, let widget = findWidget(id: widgetId) else {
                    continue
                }
                let effect: VideoEffect
                switch widget.type {
                case .text:
                    effect = createTextEffect(widget: widget)
                case .image:
                    effect = createImageEffect(widget: widget)
                default:
                    continue
                }
                slides.append(SlideshowEffectSlide(widgetId: widgetId,
                                                   effect: effect,
                                                   time: Double(slide.time)))
            }
            slideshowEffects[widget.id] = SlideshowEffect(slides: slides)
        }
    }

    private func resetWheelOfLuckEffects(widgets: [SettingsWidget]) {
        wheelOfLuckEffects.removeAll()
        for widget in widgets where widget.type == .wheelOfLuck {
            wheelOfLuckEffects[widget.id] = WheelOfLuckEffect(canvasSize: media.getCanvasSize())
        }
    }

    private func resetBingoCardEffects(widgets: [SettingsWidget]) {
        bingoCardEffects.removeAll()
        for widget in widgets where widget.type == .bingoCard {
            bingoCardEffects[widget.id] = BingoCardEffect(canvasSize: media.getCanvasSize())
        }
    }

    private func isQuickButtonOn(type: SettingsQuickButtonType) -> Bool {
        return database.quickButtons.first(where: { $0.type == type })?.isOn ?? false
    }

    private func isFaceEnabled() -> Bool {
        let settings = database.debug.face
        return settings.showBlur || settings.showBlurBackground || settings.showMoblin
    }

    private func setSceneId(id: UUID) {
        sceneSelector.selectedSceneId = id
        remoteControlStateChanged(state: RemoteControlAssistantStreamerState(scene: id))
        if isWatchLocal() {
            sendSceneToWatch(id: sceneSelector.selectedSceneId)
        }
        let showMediaPlayerControls = findEnabledScene(id: id)?.videoSource.cameraPosition == .mediaPlayer
        if showMediaPlayerControls != streamOverlay.showMediaPlayerControls {
            streamOverlay.showMediaPlayerControls = showMediaPlayerControls
        }
    }

    private func sceneUpdatedOff() {
        media.unregisterAllEffects()
        createGlobalVideoEffects()
        for effect in browserEffects.values {
            effect.stop()
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
            guard lut.enabled else {
                continue
            }
            guard let lutEffect = lutEffects[lut.id] else {
                continue
            }
            effects.append(lutEffect)
        }
        effects += registerGlobalVideoEffects(scene: scene)
        var addedScenes: [SettingsScene] = []
        var needsSpeechToText = false
        enabledAlertsEffects.removeAll()
        enabledSnapshotEffects.removeAll()
        enabledChatEffects.removeAll()
        var scene = scene
        if let remoteSceneWidget = remoteSceneWidgets.first {
            scene = scene.clone()
            scene.widgets.append(SettingsSceneWidget(widgetId: remoteSceneWidget.id))
        }
        addSceneEffects(scene, &effects, &addedScenes, &needsSpeechToText)
        if !drawOnStream.lines.isEmpty {
            effects.append(drawOnStreamEffect)
        }
        effects += registerGlobalVideoEffectsOnTop()
        media.setPendingAfterAttachEffects(effects: effects, rotation: scene.videoSourceRotation)
        for effect in browserEffects.values where !effects.contains(effect) {
            effect.setSceneWidget(sceneWidget: nil, crops: [])
        }
        for effect in mapEffects.values where !effects.contains(effect) {
            effect.setSceneWidget(sceneWidget: nil)
        }
        for effect in chatEffects.values where !effects.contains(effect) {
            effect.stop()
        }
        for (id, scoreboardEffect) in scoreboardEffects where !effects.contains(scoreboardEffect) {
            if isWatchLocal() {
                sendRemoveScoreboardToWatch(id: id)
            }
        }
        media.setSpeechToText(enabled: needsSpeechToText)
        if attachCamera {
            attachSingleLayout(scene: scene)
        } else {
            media.usePendingAfterAttachEffects()
        }
        // To do: Should update on first frame in draw effect instead.
        if !drawOnStream.lines.isEmpty {
            drawOnStreamEffect.updateOverlay(
                videoSize: media.getCanvasSize(),
                size: drawOnStreamSize,
                lines: drawOnStream.lines,
                mirror: streamOverlay.isFrontCameraSelected && !database.mirrorFrontCameraOnStream
            )
        }
    }

    private func addSceneEffects(
        _ scene: SettingsScene,
        _ effects: inout [VideoEffect],
        _ addedScenes: inout [SettingsScene],
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
                addSceneImageEffects(sceneWidget, widget, &effects)
            case .text:
                addSceneTextEffects(sceneWidget, widget, &effects, &needsSpeechToText)
            case .browser:
                addSceneBrowserEffects(sceneWidget, widget, scene, &effects)
            case .crop:
                addSceneCropEffects(widget, scene, &effects)
            case .map:
                addSceneMapEffects(sceneWidget, widget, &effects)
            case .scene:
                addSceneSceneEffects(widget, &effects, &addedScenes, &needsSpeechToText)
            case .slideshow:
                addSceneSlideshowEffects(sceneWidget, widget, &effects)
            case .qrCode:
                addSceneQrCodeEffects(sceneWidget, widget, &effects)
            case .alerts:
                addSceneAlertsEffects(sceneWidget, widget, &effects, &needsSpeechToText)
            case .videoSource:
                addSceneVideoSourceEffects(sceneWidget, widget, &effects)
            case .scoreboard:
                addSceneScoreboardEffects(sceneWidget, widget, &effects)
            case .vTuber:
                addSceneVTuberEffects(sceneWidget, widget, &effects)
            case .pngTuber:
                addScenePngTuberEffects(sceneWidget, widget, &effects)
            case .snapshot:
                addSceneSnapshotEffects(sceneWidget, widget, &effects)
            case .chat:
                addSceneChatEffects(sceneWidget, widget, &effects)
            case .wheelOfLuck:
                addSceneWheelOfLuckEffects(sceneWidget, widget, &effects)
            case .bingoCard:
                addSceneBingoCardEffects(sceneWidget, widget, &effects)
            }
        }
    }

    private func addSceneImageEffects(_ sceneWidget: SettingsSceneWidget,
                                      _ widget: SettingsWidget,
                                      _ effects: inout [VideoEffect])
    {
        guard let effect = imageEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effects.append(effect)
    }

    private func addSceneTextEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect],
        _ needsSpeechToText: inout Bool
    ) {
        guard let effect = textEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effects.append(effect)
        if widget.text.needsSubtitles {
            needsSpeechToText = true
        }
    }

    private func addSceneBrowserEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ scene: SettingsScene,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = browserEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(
            sceneWidget: sceneWidget.clone(),
            crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.id)
        )
        effects.append(effect)
    }

    private func addSceneCropEffects(
        _ widget: SettingsWidget,
        _ scene: SettingsScene,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = browserEffects[widget.crop.sourceWidgetId], !effects.contains(effect) else {
            return
        }
        let sceneWidget: SettingsSceneWidget?
        if findWidget(id: widget.crop.sourceWidgetId)?.enabled == true {
            sceneWidget = findSceneWidget(scene: scene, widgetId: widget.crop.sourceWidgetId)
        } else {
            sceneWidget = nil
        }
        effect.setSceneWidget(
            sceneWidget: sceneWidget?.clone(),
            crops: findWidgetCrops(scene: scene, sourceWidgetId: widget.crop.sourceWidgetId)
        )
        effects.append(effect)
    }

    private func addSceneMapEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = mapEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effects.append(effect)
    }

    private func addSceneSceneEffects(
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect],
        _ addedScenes: inout [SettingsScene],
        _ needsSpeechToText: inout Bool
    ) {
        guard let sceneWidgetScene = getLocalAndRemoteScenes()
            .first(where: { $0.id == widget.scene.sceneId })
        else {
            return
        }
        addSceneEffects(sceneWidgetScene, &effects, &addedScenes, &needsSpeechToText)
    }

    private func addSceneSlideshowEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = slideshowEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effects.append(effect)
    }

    private func addSceneQrCodeEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = qrCodeEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effects.append(effect)
    }

    private func addSceneAlertsEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect],
        _ needsSpeechToText: inout Bool
    ) {
        guard let effect = alertsEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setPosition(x: sceneWidget.layout.x, y: sceneWidget.layout.y)
        enabledAlertsEffects.append(effect)
        effects.append(effect)
        if widget.alerts.needsSubtitles {
            needsSpeechToText = true
        }
    }

    private func addSceneVideoSourceEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = videoSourceEffects[widget.id], !effects.contains(effect) else {
            return
        }
        if let videoSourceId = getVideoSourceId(cameraId: widget.videoSource.toCameraId()) {
            effect.setVideoSourceId(videoSourceId: videoSourceId)
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effect.setSettings(settings: widget.videoSource.toEffectSettings())
        effects.append(effect)
    }

    private func addSceneScoreboardEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = scoreboardEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        DispatchQueue.main.async {
            effect.update(scoreboard: widget.scoreboard, players: self.database.scoreboardPlayers)
        }
        if isWatchLocal() {
            switch widget.scoreboard.type {
            case .padel:
                sendUpdatePadelScoreboardToWatch(id: widget.id, padel: widget.scoreboard.padel)
            case .generic:
                sendUpdateGenericScoreboardToWatch(id: widget.id, generic: widget.scoreboard.generic)
            }
        }
        effects.append(effect)
    }

    private func addSceneVTuberEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = vTuberEffects[widget.id], !effects.contains(effect) else {
            return
        }
        if let videoSourceId = getVideoSourceId(cameraId: widget.vTuber.toCameraId()) {
            effect.setVideoSourceId(videoSourceId: videoSourceId)
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effect.setSettings(
            cameraFieldOfView: widget.vTuber.cameraFieldOfView,
            cameraPositionY: widget.vTuber.cameraPositionY,
            mirror: widget.vTuber.mirror
        )
        effects.append(effect)
    }

    private func addScenePngTuberEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = pngTuberEffects[widget.id], !effects.contains(effect) else {
            return
        }
        if let videoSourceId = getVideoSourceId(cameraId: widget.pngTuber.toCameraId()) {
            effect.setVideoSourceId(videoSourceId: videoSourceId)
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effect.setSettings(mirror: widget.pngTuber.mirror)
        effects.append(effect)
    }

    private func addSceneSnapshotEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = snapshotEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        enabledSnapshotEffects.append(effect)
        effects.append(effect)
    }

    private func addSceneChatEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = chatEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effect.start()
        enabledChatEffects.append(effect)
        effects.append(effect)
    }

    private func addSceneWheelOfLuckEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = wheelOfLuckEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSettings(settings: widget.wheelOfLuck)
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effects.append(effect)
    }

    private func addSceneBingoCardEffects(
        _ sceneWidget: SettingsSceneWidget,
        _ widget: SettingsWidget,
        _ effects: inout [VideoEffect]
    ) {
        guard let effect = bingoCardEffects[widget.id], !effects.contains(effect) else {
            return
        }
        effect.setSettings(settings: widget.bingoCard)
        effect.setSceneWidget(sceneWidget: sceneWidget.clone())
        effects.append(effect)
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

    private func findWidgetCrops(scene: SettingsScene, sourceWidgetId: UUID) -> [WidgetCrop] {
        var crops: [WidgetCrop] = []
        for widget in getSceneWidgets(scene: scene, onlyEnabled: true) {
            guard widget.widget.type == .crop else {
                continue
            }
            let crop = widget.widget.crop
            guard crop.sourceWidgetId == sourceWidgetId else {
                continue
            }
            crops.append(WidgetCrop(crop: crop.clone(), sceneWidget: widget.sceneWidget.clone()))
        }
        return crops
    }

    private func isCaptureDeviceWidgetInternal(widget: SettingsWidget,
                                               addedSceneIds: inout Set<UUID>) -> Bool
    {
        switch widget.type {
        case .scene:
            if addedSceneIds.contains(widget.scene.sceneId) {
                return false
            }
            addedSceneIds.insert(widget.scene.sceneId)
            if let scene = database.scenes.first(where: { $0.id == widget.scene.sceneId }) {
                for widget in getSceneWidgets(scene: scene, onlyEnabled: false) where
                    isCaptureDeviceWidgetInternal(widget: widget.widget, addedSceneIds: &addedSceneIds)
                {
                    return true
                }
            }
            return false
        case .videoSource:
            return widget.videoSource.videoSource.isCaptureDevice()
        case .vTuber:
            return widget.vTuber.videoSource.isCaptureDevice()
        case .pngTuber:
            return widget.pngTuber.videoSource.isCaptureDevice()
        default:
            return false
        }
    }

    private func getSceneWidgetsInternal(_ scene: SettingsScene,
                                         _ onlyEnabled: Bool,
                                         _ addedSceneIds: inout Set<UUID>) -> [WidgetInScene]
    {
        var widgets: [WidgetInScene] = []
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            guard !onlyEnabled || widget.enabled else {
                continue
            }
            if widget.type == .scene {
                if addedSceneIds.contains(widget.scene.sceneId) {
                    continue
                }
                widgets.append(WidgetInScene(widget: widget, sceneWidget: sceneWidget))
                addedSceneIds.insert(widget.scene.sceneId)
                if let scene = database.scenes.first(where: { $0.id == widget.scene.sceneId }) {
                    widgets += getSceneWidgetsInternal(scene, onlyEnabled, &addedSceneIds)
                }
            } else {
                widgets.append(WidgetInScene(widget: widget, sceneWidget: sceneWidget))
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
            for effect in getTextEffects(id: widget.id) {
                effect.setLapTimes(lapTimes: widget.text.lapTimes.map { $0.lapTimes })
            }
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
            let weather = weatherManager.getLatestWeather()?.currentWeather
            let placemark = geographyManager.getLatestPlacemark()
            stats = TextEffectStats(
                timestamp: timestamp,
                bitrate: bitrate.speedMbpsOneDecimal,
                bitrateAndTotal: bitrate.speedAndTotal,
                resolution: currentResolution,
                fps: currentFps,
                date: now,
                debugOverlayLines: debugOverlay.debugLines,
                speed: format(speed: location?.speed ?? 0),
                averageSpeed: format(speed: averageSpeed),
                altitude: format(altitude: location?.altitude ?? 0),
                distance: getDistance(),
                slope: "\(Int(slopePercent))%",
                conditions: weather?.symbolName,
                temperature: weather?.temperature,
                feelsLikeTemperature: weather?.apparentTemperature,
                windSpeed: weather?.wind.speed,
                windGust: weather?.wind.gust,
                country: placemark?.country ?? "",
                countryFlag: emojiFlag(countryCode: placemark?.isoCountryCode),
                state: placemark?.administrativeArea,
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
        for effect in textEffects.values {
            effect.updateStats(stats: stats)
        }
        for effect in slideshowEffects.values {
            for slide in effect.slides {
                if let textEffect = slide.effect as? TextEffect {
                    textEffect.updateStats(stats: stats)
                }
            }
        }
    }

    private func getBrowserTitle() -> String {
        if showBrowser {
            return getWebBrowser().title ?? ""
        } else {
            return ""
        }
    }

    private func getBuiltinCameraDevicesInScene(scene: SettingsScene,
                                                devices: inout [CaptureDevice],
                                                addedSceneIds: inout Set<UUID>)
    {
        guard !addedSceneIds.contains(scene.id) else {
            return
        }
        addedSceneIds.insert(scene.id)
        for sceneWidget in scene.widgets {
            guard let widget = findWidget(id: sceneWidget.widgetId), widget.enabled else {
                continue
            }
            switch widget.type {
            case .videoSource:
                getBuiltinCameraDevices(videoSource: widget.videoSource.videoSource, devices: &devices)
            case .vTuber:
                getBuiltinCameraDevices(videoSource: widget.vTuber.videoSource, devices: &devices)
            case .pngTuber:
                getBuiltinCameraDevices(videoSource: widget.pngTuber.videoSource, devices: &devices)
            case .scene:
                getBuiltinCameraDevicesForSceneWidget(scene: widget.scene,
                                                      devices: &devices,
                                                      addedSceneIds: &addedSceneIds)
            default:
                break
            }
        }
    }

    private func getBuiltinCameraDevices(videoSource: SettingsVideoSource, devices: inout [CaptureDevice]) {
        if let cameraId = videoSource.getCaptureDeviceCameraId(),
           let device = AVCaptureDevice(uniqueID: cameraId)
        {
            if !devices.contains(where: { $0.device == device }) {
                devices.append(makeCaptureDevice(device: device))
            }
        }
    }

    private func getBuiltinCameraDevicesForSceneWidget(scene: SettingsWidgetScene,
                                                       devices: inout [CaptureDevice],
                                                       addedSceneIds: inout Set<UUID>)
    {
        if let scene = database.scenes.first(where: { $0.id == scene.sceneId }) {
            getBuiltinCameraDevicesInScene(scene: scene,
                                           devices: &devices,
                                           addedSceneIds: &addedSceneIds)
        }
    }

    private func createSceneWidget(widget: SettingsWidget) -> SettingsSceneWidget {
        let sceneWidget = SettingsSceneWidget(widgetId: widget.id)
        switch widget.type {
        case .image, .slideshow:
            sceneWidget.layout.size = 30
        case .map, .qrCode:
            sceneWidget.layout.size = 23
        case .videoSource, .vTuber, .pngTuber:
            sceneWidget.layout.size = 28
            sceneWidget.layout.alignment = .bottomRight
        case .snapshot:
            sceneWidget.layout.size = 40
            sceneWidget.layout.alignment = .topRight
        case .chat:
            sceneWidget.layout.alignment = .bottomLeft
        case .alerts:
            sceneWidget.layout.x = 20
            sceneWidget.layout.y = 5
        case .scoreboard:
            sceneWidget.layout.x = 0.78
            sceneWidget.layout.y = 1.388
        case .wheelOfLuck:
            sceneWidget.layout.alignment = .topRight
            sceneWidget.layout.x = 1.3
            sceneWidget.layout.y = 31
        case .bingoCard:
            sceneWidget.layout.alignment = .topRight
            sceneWidget.layout.x = 1.3
            sceneWidget.layout.y = 33
            sceneWidget.layout.size = 33
        default:
            break
        }
        sceneWidget.layout.updateXString()
        sceneWidget.layout.updateYString()
        sceneWidget.layout.updateSizeString()
        return sceneWidget
    }

    private func updateTimers(
        _ text: SettingsWidgetText,
        _ textEffect: TextEffect,
        _ parts: [TextFormatPart]
    ) {
        let length = parts.filter { $0 == .timer }.count
        text.timers.truncate(length: length, create: { .init() })
        textEffect.setTimersEndTime(endTimes: text.timers.map {
            .now.advanced(by: .seconds(utcTimeDeltaFromNow(to: $0.endTime)))
        })
    }

    private func updateStopwatches(
        _ text: SettingsWidgetText,
        _ textEffect: TextEffect,
        _ parts: [TextFormatPart]
    ) {
        let length = parts.filter { $0 == .stopwatch }.count
        text.stopwatches.truncate(length: length, create: { .init() })
        textEffect.setStopwatches(stopwatches: text.stopwatches.map { $0.clone() })
    }

    private func updateCheckboxes(
        _ text: SettingsWidgetText,
        _ textEffect: TextEffect,
        _ parts: [TextFormatPart]
    ) {
        let length = parts.filter { $0 == .checkbox }.count
        text.checkboxes.truncate(length: length, create: { .init() })
        textEffect.setCheckboxes(checkboxes: text.checkboxes.map { $0.checked })
    }

    private func updateRatings(
        _ text: SettingsWidgetText,
        _ textEffect: TextEffect,
        _ parts: [TextFormatPart]
    ) {
        let length = parts.filter { $0 == .rating }.count
        text.ratings.truncate(length: length, create: { .init() })
        textEffect.setRatings(ratings: text.ratings.map { $0.rating })
    }

    private func updateLapTimes(
        _ text: SettingsWidgetText,
        _ textEffect: TextEffect,
        _ parts: [TextFormatPart]
    ) {
        let length = parts.filter { $0 == .lapTimes }.count
        text.lapTimes.truncate(length: length, create: { .init() })
        textEffect.setLapTimes(lapTimes: text.lapTimes.map { $0.lapTimes })
    }

    private func updateSubtitles(_ text: SettingsWidgetText, _: TextEffect?, _ parts: [TextFormatPart]) {
        text.subtitles.removeAll()
        for part in parts {
            switch part {
            case let .subtitles(identifier):
                let item = SettingsWidgetTextSubtitles()
                item.identifier = identifier
                text.subtitles.append(item)
            default:
                break
            }
        }
        text.needsSubtitles = !text.subtitles.isEmpty
        reloadSpeechToText()
    }

    private func updateNeedsWeather(_ text: SettingsWidgetText, _ parts: [TextFormatPart]) {
        text.needsWeather = parts.contains(where: {
            switch $0 {
            case .conditions, .temperature:
                return true
            default:
                return false
            }
        })
        startWeatherManager()
    }

    private func updateNeedsGeography(_ text: SettingsWidgetText, _ parts: [TextFormatPart]) {
        text.needsGeography = parts.contains(where: {
            switch $0 {
            case .country, .countryFlag, .state, .city:
                return true
            default:
                return false
            }
        })
        startGeographyManager()
    }

    private func updateNeedsGForce(_ text: SettingsWidgetText, _ parts: [TextFormatPart]) {
        text.needsGForce = parts.contains(where: {
            switch $0 {
            case .gForce, .gForceRecentMax, .gForceMax:
                return true
            default:
                return false
            }
        })
        startGForceManager()
    }
}
