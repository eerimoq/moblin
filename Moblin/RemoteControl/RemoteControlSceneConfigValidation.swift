import Foundation

let remoteControlVideoSourceRotations: [Double] = [0, 90, 180, 270]

struct RemoteControlCameras {
    var ids: Set<CameraId> = []
    var cameraId: (SettingsVideoSource) -> CameraId = { _ in "" }
}

private func isValidChange<T: Equatable>(_ old: T, _ new: T, _ isValid: (T) -> Bool) -> Bool {
    old == new || isValid(new)
}

private func isValidLayoutChange(_ old: SettingsWidgetLayout, _ new: SettingsWidgetLayout) -> Bool {
    isValidChange(old.x, new.x) { (0 ... 100).contains($0) }
        && isValidChange(old.y, new.y) { (0 ... 100).contains($0) }
        && isValidChange(old.size, new.size) { (1 ... 100).contains($0) }
}

func remoteControlAllAlerts(_ alerts: SettingsWidgetAlerts) -> [SettingsWidgetAlertsAlert] {
    var all: [SettingsWidgetAlertsAlert] = [
        alerts.twitch.follows,
        alerts.twitch.subscriptions,
        alerts.twitch.raids,
        alerts.kick.subscriptions,
        alerts.kick.giftedSubscriptions,
        alerts.kick.hosts,
        alerts.kick.rewards,
        alerts.moblinCloud.tips,
    ]
    all += alerts.twitch.cheerBits.map(\.alert)
    all += alerts.kick.kickGifts.map(\.alert)
    all += alerts.chatBot.commands.map(\.alert)
    all += alerts.speechToText.strings.map(\.alert)
    return all
}

func isValidRemoteControlName<T: Named & Identifiable>(_ item: T, _ items: [T], _ oldItems: [T]) -> Bool
    where T.ID == UUID
{
    if oldItems.first(where: { $0.id == item.id })?.name == item.name {
        return true
    }
    return !item.name.isEmpty && !items.contains { $0.id != item.id && $0.name == item.name }
}

func hasUniqueRemoteControlIds<T: Identifiable>(_ items: [T]) -> Bool where T.ID == UUID {
    Set(items.map(\.id)).count == items.count
}

func isValidRemoteControlWidgetUpdate(widget: SettingsWidget,
                                      new: SettingsWidget,
                                      creating: Bool,
                                      editableTextTimers: Int,
                                      database: Database,
                                      cameras: RemoteControlCameras) -> Bool
{
    guard new.type == widget.type else {
        return false
    }
    switch widget.type {
    case .text:
        return isValidTextUpdate(widget.text, new.text, creating, editableTextTimers)
    case .browser:
        return isValidBrowserUpdate(widget.browser, new.browser, creating)
            && isValidEffectsUpdate(widget, new, database)
    case .crop:
        return isValidCropUpdate(widget.crop, new.crop, creating, database)
    case .map:
        return isValidChange(widget.map.size, new.map.size) { (500 ... 10000).contains($0) }
            && isValidChange(widget.map.delay, new.map.delay) { (0 ... 10).contains($0) }
            && isValidEffectsUpdate(widget, new, database)
    case .scene:
        return isValidSceneWidgetUpdate(widget, new, creating, database)
    case .qrCode, .image:
        return isValidEffectsUpdate(widget, new, database)
    case .snapshot:
        return isValidChange(widget.snapshot.showtime, new.snapshot.showtime) {
            [3, 5, 10, 15, 30, 60, 120].contains($0)
        }
            && isValidEffectsUpdate(widget, new, database)
    case .chat:
        return isValidChatUpdate(widget.chat, new.chat)
    case .chatEmoteCombo:
        return isValidChange(widget.chatEmoteCombo.minimumCombo, new.chatEmoteCombo.minimumCombo) {
            (2 ... 10).contains($0)
        }
            && isValidChange(widget.chatEmoteCombo.resetAfter, new.chatEmoteCombo.resetAfter) {
                (3 ... 10).contains($0)
            }
    case .slideshow:
        return isValidSlideshowUpdate(widget.slideshow, new.slideshow, creating, database)
    case .wheelOfLuck:
        return isValidWheelOfLuckUpdate(widget.wheelOfLuck, new.wheelOfLuck)
    case .bingoCard:
        return true
    case .videoSource:
        return isValidVideoSourceUpdate(widget.videoSource, new.videoSource, cameras)
            && isValidEffectsUpdate(widget, new, database)
    case .vTuber:
        return isValidVTuberUpdate(widget.vTuber, new.vTuber, cameras)
    case .pngTuber:
        return isValidCameraChange(widget.pngTuber.videoSource, new.pngTuber.videoSource, cameras)
            && isValidSensitivityUpdate(widget.pngTuber.sensitivity, new.pngTuber.sensitivity)
    case .pomodoroTimer:
        return isValidPomodoroTimerUpdate(widget.pomodoroTimer, new.pomodoroTimer, database)
    case .scoreboard:
        return isValidScoreboardUpdate(widget.scoreboard, new.scoreboard, creating, database)
    case .alerts:
        return isValidAlertsUpdate(widget.alerts, new.alerts, database)
    }
}

func isValidRemoteControlSceneUpdate(scene: SettingsScene,
                                     new: SettingsScene,
                                     database: Database,
                                     cameras: RemoteControlCameras) -> Bool
{
    for sceneWidget in new.widgets {
        if let oldSceneWidget = scene.widgets.first(where: { $0.id == sceneWidget.id }) {
            guard oldSceneWidget.widgetId == sceneWidget.widgetId,
                  isValidLayoutChange(oldSceneWidget.layout, sceneWidget.layout)
            else {
                return false
            }
        } else {
            guard database.findWidget(id: sceneWidget.widgetId) != nil,
                  isValidLayoutChange(SettingsWidgetLayout(), sceneWidget.layout)
            else {
                return false
            }
        }
    }
    return isValidCameraChange(scene.videoSource, new.videoSource, cameras)
        && isValidChange(scene.videoSourceRotation, new.videoSourceRotation) {
            remoteControlVideoSourceRotations.contains($0)
        }
        && isValidChange(scene.videoStabilizationMode, new.videoStabilizationMode) {
            videoStabilizationModes.contains($0)
        }
        && isValidChange(scene.quickSwitchGroup, new.quickSwitchGroup) { group in
            group.map { (1 ... 4).contains($0) } ?? true
        }
        && isValidChange(scene.micId, new.micId) { micId in database.mics.mics.contains { $0.id == micId } }
}

func isValidRemoteControlScene(scene: SettingsScene, scenes: [SettingsScene], database: Database) -> Bool {
    isValidRemoteControlName(scene, scenes, database.scenes)
        && hasUniqueRemoteControlIds(scene.widgets)
        && !introducesDuplicatedWidgets(scenes: scenes, widgets: database.widgets, database: database)
}

func isValidRemoteControlWidgetScenes(widget: SettingsWidget, sceneIds: [UUID], database: Database) -> Bool {
    guard Set(sceneIds).count == sceneIds.count,
          sceneIds.allSatisfy({ database.findScene(id: $0) != nil })
    else {
        return false
    }
    let scenes = database.scenes.map { scene in
        guard sceneIds.contains(scene.id) else {
            return scene
        }
        let newScene = SettingsScene(name: scene.name)
        newScene.id = scene.id
        newScene.widgets = scene.widgets + [SettingsSceneWidget(widgetId: widget.id)]
        return newScene
    }
    return !introducesDuplicatedWidgets(
        scenes: scenes,
        widgets: database.widgets + [widget],
        database: database
    )
}

func remoteControlMergeSceneWidgets(_ sceneWidgets: [SettingsSceneWidget],
                                    _ newSceneWidgets: [SettingsSceneWidget]) -> [SettingsSceneWidget]
{
    newSceneWidgets.map { sceneWidget in
        let oldSceneWidget = sceneWidgets.first { $0.id == sceneWidget.id }
        var layout = sceneWidget.layout
        if layout.alignment != (oldSceneWidget?.layout.alignment ?? SettingsWidgetLayout().alignment),
           layout.alignment.isHorizontalOrVerticalCenter()
        {
            layout.positioningLock = false
        }
        guard let oldSceneWidget else {
            sceneWidget.layout = layout
            return sceneWidget
        }
        oldSceneWidget.layout = layout
        return oldSceneWidget
    }
}

private func introducesDuplicatedWidgets(scenes: [SettingsScene],
                                         widgets: [SettingsWidget],
                                         database: Database) -> Bool
{
    let before = SceneResolver(scenes: database.scenes, widgets: widgets)
    let after = SceneResolver(scenes: scenes, widgets: widgets)
    return scenes.contains { scene in
        let beforeCounts = database.findScene(id: scene.id).map {
            before.resolve($0, includeDisabledSceneWidgets: true).duplicatedWidgetCounts()
        } ?? [:]
        return after.resolve(scene, includeDisabledSceneWidgets: true).duplicatedWidgetCounts()
            .contains { widgetId, count in
                count > beforeCounts[widgetId, default: 0]
            }
    }
}

private func isValidTextUpdate(_ text: SettingsWidgetText, _ newText: SettingsWidgetText,
                               _ creating: Bool, _ editableTimers: Int) -> Bool
{
    (!creating || !newText.formatString.isEmpty)
        && isValidChange(text.fontSize, newText.fontSize) { (10 ... 200).contains($0) }
        && isValidChange(text.width, newText.width) { $0 > 0 && $0 < 4000 }
        && isValidChange(text.cornerRadius, newText.cornerRadius) { $0 >= 0 && $0 < 1000 }
        && isValidChange(text.delay, newText.delay) { (0 ... 10).contains($0) }
        && newText.timers.enumerated().allSatisfy { index, newTimer in
            let timer = index < text.timers.count ? text.timers[index] : SettingsWidgetTextTimer()
            return isValidChange(timer.delta, newTimer.delta) {
                index < editableTimers && [1, 2, 5, 15, 60].contains($0)
            }
        }
}

private func isValidBrowserUpdate(_ browser: SettingsWidgetBrowser,
                                  _ newBrowser: SettingsWidgetBrowser,
                                  _ creating: Bool) -> Bool
{
    let url = newBrowser.url.trim()
    return (!creating || !url.isEmpty && isValidHttpUrl(url: url) == nil)
        && isValidChange(browser.url, newBrowser.url) { isValidHttpUrl(url: $0.trim()) == nil }
        && isValidChange(browser.width, newBrowser.width) { $0 > 0 && $0 < 4000 }
        && isValidChange(browser.height, newBrowser.height) { $0 > 0 && $0 < 4000 }
        && isValidChange(browser.baseFps, newBrowser.baseFps) { (1 ... 15).contains($0) }
}

private func isValidCropUpdate(_ crop: SettingsWidgetCrop,
                               _ newCrop: SettingsWidgetCrop,
                               _ creating: Bool,
                               _ database: Database) -> Bool
{
    isValidChange(crop.sourceWidgetId, newCrop.sourceWidgetId) { sourceWidgetId in
        guard let sourceWidget = database.findWidget(id: sourceWidgetId) else {
            return creating
        }
        return sourceWidget.type == .browser
    }
        && isValidChange(crop.x, newCrop.x) { $0 >= 0 }
        && isValidChange(crop.y, newCrop.y) { $0 >= 0 }
        && isValidChange(crop.width, newCrop.width) { $0 > 0 }
        && isValidChange(crop.height, newCrop.height) { $0 > 0 }
}

private func isValidSceneWidgetUpdate(_ widget: SettingsWidget,
                                      _ new: SettingsWidget,
                                      _ creating: Bool,
                                      _ database: Database) -> Bool
{
    isValidChange(widget.scene.sceneId, new.scene.sceneId) { sceneId in
        guard let sceneId else {
            return true
        }
        guard database.scenes.contains(where: { $0.id == sceneId }) else {
            return creating
        }
        return SceneResolver(scenes: database.scenes, widgets: database.widgets)
            .selectableScenes(widget: widget)
            .contains { $0.id == sceneId }
    }
}

private func isValidChatUpdate(_ chat: SettingsWidgetChat, _ newChat: SettingsWidgetChat) -> Bool {
    isValidChange(chat.fontSize, newChat.fontSize) { (10 ... 50).contains($0) }
        && isValidChange(chat.maximumNumberOfMessages, newChat.maximumNumberOfMessages) {
            (1 ... 5).contains($0)
        }
        && isValidChange(chat.height, newChat.height) { (0.1 ... 1).contains($0) }
}

private func isValidSlideshowUpdate(_ slideshow: SettingsWidgetSlideshow,
                                    _ newSlideshow: SettingsWidgetSlideshow,
                                    _ creating: Bool,
                                    _ database: Database) -> Bool
{
    guard !creating || !newSlideshow.slides.isEmpty else {
        return false
    }
    return newSlideshow.slides.allSatisfy { slide in
        let oldSlide = slideshow.slides.first { $0.id == slide.id } ?? SettingsWidgetSlideshowSlide()
        return isValidChange(oldSlide.widgetId, slide.widgetId) { widgetId in
            guard let widgetId else {
                return true
            }
            return database.widgets.contains { $0.id == widgetId && [.text, .image].contains($0.type) }
        }
            && isValidChange(oldSlide.time, slide.time) {
                [5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 300].contains($0)
            }
    }
}

private func isValidWheelOfLuckUpdate(_ wheelOfLuck: SettingsWidgetWheelOfLuck,
                                      _ newWheelOfLuck: SettingsWidgetWheelOfLuck) -> Bool
{
    !newWheelOfLuck.options.isEmpty && newWheelOfLuck.options.allSatisfy { option in
        let oldOption = wheelOfLuck.options.first { $0.id == option.id } ?? SettingsWidgetWheelOfLuckOption()
        return isValidChange(oldOption.weight, option.weight) { wheelOfLuckOptionWeights.contains($0) }
            && isValidChange(oldOption.function, option.function) {
                ![.zoomIn, .zoomOut, .gimbalUp, .gimbalDown, .gimbalLeft, .gimbalRight, .gimbalPreset]
                    .contains($0)
            }
    }
}

private func isValidVideoSourceUpdate(_ videoSource: SettingsWidgetVideoSource,
                                      _ newVideoSource: SettingsWidgetVideoSource,
                                      _ cameras: RemoteControlCameras) -> Bool
{
    isValidCameraChange(videoSource.videoSource, newVideoSource.videoSource, cameras)
        && isValidChange(videoSource.rotation, newVideoSource.rotation) {
            remoteControlVideoSourceRotations.contains($0)
        }
        && isValidChange(videoSource.trackFaceZoom, newVideoSource.trackFaceZoom) { (0 ... 1).contains($0) }
}

private func isValidVTuberUpdate(_ vTuber: SettingsWidgetVTuber,
                                 _ newVTuber: SettingsWidgetVTuber,
                                 _ cameras: RemoteControlCameras) -> Bool
{
    isValidCameraChange(vTuber.videoSource, newVTuber.videoSource, cameras)
        && isValidChange(vTuber.cameraPositionY, newVTuber.cameraPositionY) { (1 ... 2).contains($0) }
        && isValidChange(vTuber.cameraFieldOfView, newVTuber.cameraFieldOfView) { (10 ... 30).contains($0) }
        && isValidChange(vTuber.armsAngle, newVTuber.armsAngle) { (20 ... 90).contains($0) }
        && isValidSensitivityUpdate(vTuber.sensitivity, newVTuber.sensitivity)
}

private func isValidPomodoroTimerUpdate(_ pomodoroTimer: SettingsWidgetPomodoroTimer,
                                        _ newPomodoroTimer: SettingsWidgetPomodoroTimer,
                                        _ database: Database) -> Bool
{
    let isValidSoundId = { (soundId: UUID?) in
        soundId
            .map { soundId in database.alertsMediaGallery.allSounds().contains { $0.id == soundId } } ?? true
    }
    return isValidChange(pomodoroTimer.focusDuration, newPomodoroTimer.focusDuration) {
        [1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120].contains($0)
    }
        && isValidChange(pomodoroTimer.breakDuration, newPomodoroTimer.breakDuration) {
            [1, 2, 3, 5, 7, 10, 15, 20, 25, 30].contains($0)
        }
        && isValidChange(pomodoroTimer.width, newPomodoroTimer.width) { (1 ... 5).contains($0) }
        && isValidChange(
            pomodoroTimer.focusToBreakSoundId,
            newPomodoroTimer.focusToBreakSoundId,
            isValidSoundId
        )
        && isValidChange(
            pomodoroTimer.breakToFocusSoundId,
            newPomodoroTimer.breakToFocusSoundId,
            isValidSoundId
        )
}

private func isValidScoreboardUpdate(_ scoreboard: SettingsWidgetScoreboard,
                                     _ newScoreboard: SettingsWidgetScoreboard,
                                     _ creating: Bool,
                                     _ database: Database) -> Bool
{
    let isValidPlayerId = { (playerId: UUID) in
        creating || database.scoreboardPlayers.contains { $0.id == playerId }
    }
    let padel = scoreboard.padel
    let newPadel = newScoreboard.padel
    let golf = scoreboard.golf
    let newGolf = newScoreboard.golf
    let modular = scoreboard.modular
    let newModular = newScoreboard.modular
    return isValidChange(padel.homePlayer1, newPadel.homePlayer1, isValidPlayerId)
        && isValidChange(padel.homePlayer2, newPadel.homePlayer2, isValidPlayerId)
        && isValidChange(padel.awayPlayer1, newPadel.awayPlayer1, isValidPlayerId)
        && isValidChange(padel.awayPlayer2, newPadel.awayPlayer2, isValidPlayerId)
        && isValidChange(scoreboard.generic.clock.maximum, newScoreboard.generic.clock.maximum) {
            (1 ... 180).contains($0)
        }
        && isValidChange(golf.numberOfHoles, newGolf.numberOfHoles) { [9, 18].contains($0) }
        && isValidChange(golf.pars, newGolf.pars) { $0.allSatisfy { (1 ... 9).contains($0) } }
        && isValidChange(golf.players.count, newGolf.players.count) { $0 <= 4 }
        && isValidChange(modular.clock.maximum, newModular.clock.maximum) { (1 ... 180).contains($0) }
        && isValidChange(modular.width, newModular.width) { (100 ... 1000).contains($0) }
        && isValidChange(modular.rowHeight, newModular.rowHeight) { (10 ... 150).contains($0) }
}

private func isValidAlertsUpdate(_ alerts: SettingsWidgetAlerts,
                                 _ newAlerts: SettingsWidgetAlerts,
                                 _ database: Database) -> Bool
{
    let oldAlerts = remoteControlAllAlerts(alerts)
    return remoteControlAllAlerts(newAlerts).allSatisfy { alert in
        guard let oldAlert = oldAlerts.first(where: { $0.id == alert.id }) else {
            return isValidAlertUpdate(SettingsWidgetAlertsAlert(), alert, nil)
        }
        return isValidAlertUpdate(oldAlert, alert, database)
    }
        && isValidChange(alerts.aiEnabled, newAlerts.aiEnabled) { !$0 || newAlerts.ai.isConfigured() }
        && isValidChange(alerts.ai.baseUrl, newAlerts.ai.baseUrl) { isValidHttpUrl(url: $0) == nil }
}

private func isValidAlertUpdate(_ old: SettingsWidgetAlertsAlert,
                                _ new: SettingsWidgetAlertsAlert,
                                _ mediaDatabase: Database?) -> Bool
{
    if let mediaDatabase {
        guard isValidChange(
                  old.imageId,
                  new.imageId,
                  { imageId in mediaDatabase.alertsMediaGallery.allImages().contains { $0.id == imageId } }
              ),
              isValidChange(
                  old.soundId,
                  new.soundId,
                  { soundId in mediaDatabase.alertsMediaGallery.allSounds().contains { $0.id == soundId } }
              )
        else {
            return false
        }
    }
    return isValidChange(old.imageLoopCount, new.imageLoopCount) { (1 ... 10).contains($0) }
        && isValidChange(old.fontSize, new.fontSize) { (10 ... 80).contains($0) }
        && isValidChange(old.textToSpeechDelay, new.textToSpeechDelay) { (0 ... 5).contains($0) }
}

private func isValidCameraChange(_ old: SettingsVideoSource,
                                 _ new: SettingsVideoSource,
                                 _ cameras: RemoteControlCameras) -> Bool
{
    isValidChange(cameras.cameraId(old), cameras.cameraId(new)) { cameras.ids.contains($0) }
}

private func isValidSensitivityUpdate(_ old: SettingsSensitivity, _ new: SettingsSensitivity) -> Bool {
    isValidChange(old.mouth, new.mouth) { (0.05 ... 3).contains($0) }
        && isValidChange(old.eyes, new.eyes) { (0.05 ... 5).contains($0) }
}

private func isValidEffectsUpdate(_ widget: SettingsWidget,
                                  _ new: SettingsWidget,
                                  _ database: Database) -> Bool
{
    guard hasUniqueRemoteControlIds(new.effects) else {
        return false
    }
    return new.effects.allSatisfy { effect in
        if let oldEffect = widget.effects.first(where: { $0.id == effect.id }) {
            return oldEffect.type == effect.type && isValidEffectUpdate(oldEffect, effect, database)
        }
        let defaultEffect = SettingsVideoEffect()
        defaultEffect.type = effect.type
        return isValidEffectUpdate(defaultEffect, effect, database)
    }
}

private func isValidEffectUpdate(_ old: SettingsVideoEffect,
                                 _ new: SettingsVideoEffect,
                                 _ database: Database) -> Bool
{
    switch new.type {
    case .shape:
        let oldShape = old.shape
        let newShape = new.shape
        return isValidChange(oldShape.cornerRadius, newShape.cornerRadius) { (0 ... 1).contains($0) }
            && isValidChange(oldShape.borderWidth, newShape.borderWidth) { (0 ... 1).contains($0) }
            && isValidChange(oldShape.cropX, newShape.cropX) { (0 ... 1).contains($0) }
            && isValidChange(oldShape.cropY, newShape.cropY) { (0 ... 1).contains($0) }
            && isValidChange(oldShape.cropWidth, newShape.cropWidth) { (0 ... 1).contains($0) }
            && isValidChange(oldShape.cropHeight, newShape.cropHeight) { (0 ... 1).contains($0) }
    case .dewarp360:
        let oldDewarp = old.dewarp360
        let newDewarp = new.dewarp360
        return isValidChange(oldDewarp.pan, newDewarp.pan) { (-180 ... 180).contains($0) }
            && isValidChange(oldDewarp.tilt, newDewarp.tilt) { (-90 ... 90).contains($0) }
            && isValidChange(oldDewarp.inverseFieldOfView, newDewarp.inverseFieldOfView) {
                (30 ... 170).contains($0)
            }
    case .anamorphicLens:
        return isValidChange(old.anamorphicLens.scale, new.anamorphicLens.scale) { $0 > 0 && $0 <= 10 }
    case .lut:
        return isValidChange(old.lut.lut, new.lut.lut) { lutId in
            lutId.map { lutId in database.color.allLuts().contains { $0.id == lutId } } ?? true
        }
    case .opacity:
        return isValidChange(old.opacity.opacity, new.opacity.opacity) { (0 ... 1).contains($0) }
    case .mask:
        let oldPoints = old.mask.points.map { [$0.x, $0.y] }
        let newPoints = new.mask.points.map { [$0.x, $0.y] }
        return isValidChange(oldPoints, newPoints) { points in
            points.count >= 3 && points.allSatisfy { $0.allSatisfy { (0 ... 100).contains($0) } }
        }
            && isValidChange(old.mask.tension, new.mask.tension) { (0 ... 0.5).contains($0) }
    case .removeBackground, .grayScale, .sepia, .whirlpool, .pinch:
        return true
    }
}
