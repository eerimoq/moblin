import Foundation

private let effectsWidgetTypes: [SettingsWidgetType] = [
    .image,
    .browser,
    .map,
    .qrCode,
    .snapshot,
    .videoSource,
]
private let noReloadWidgetTypes: [SettingsWidgetType] = [
    .alerts,
    .wheelOfLuck,
    .bingoCard,
    .chat,
    .chatEmoteCombo,
    .pomodoroTimer,
]
private let videoSourceRotations: [Double] = [0, 90, 180, 270]

private func isValidChange<T: Equatable>(_ old: T, _ new: T, _ isValid: (T) -> Bool) -> Bool {
    old == new || isValid(new)
}

private func isValidLayoutChange(_ old: SettingsWidgetLayout, _ new: SettingsWidgetLayout) -> Bool {
    isValidChange(old.x, new.x) { (0 ... 100).contains($0) }
        && isValidChange(old.y, new.y) { (0 ... 100).contains($0) }
        && isValidChange(old.size, new.size) { (1 ... 100).contains($0) }
}

private func allAlerts(_ alerts: SettingsWidgetAlerts) -> [SettingsWidgetAlertsAlert] {
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

struct RemoteControlWidgetChanges {
    let enabled: Bool
    let camera: Bool
    let formatString: Bool
}

extension Model {
    func remoteControlMakeWidget(widget: SettingsWidget) -> SettingsWidget? {
        switch widget.type {
        case .text:
            guard !widget.text.formatString.isEmpty else {
                return nil
            }
        case .browser:
            guard isValidHttpUrl(url: widget.browser.url.trim()) == nil else {
                return nil
            }
        case .slideshow:
            guard !widget.slideshow.slides.isEmpty else {
                return nil
            }
        default:
            break
        }
        if widget.name.isEmpty {
            widget.name = makeUniqueName(name: SettingsWidget.baseName, existingNames: database.widgets)
        }
        let newWidget = SettingsWidget(name: widget.name)
        newWidget.id = widget.id
        newWidget.type = widget.type
        newWidget.text.formatString = ""
        guard remoteControlIsValidWidgetUpdate(widget: newWidget, new: widget) else {
            return nil
        }
        _ = remoteControlApplyWidgetUpdate(widget: newWidget, new: widget)
        return newWidget
    }

    func remoteControlIsValidWidgetUpdate(widget: SettingsWidget, new: SettingsWidget) -> Bool {
        guard new.type == widget.type, isValidEffectsUpdate(widget: widget, new: new) else {
            return false
        }
        switch widget.type {
        case .text:
            return isValidTextUpdate(widget.text, new.text)
        case .browser:
            return isValidBrowserUpdate(widget.browser, new.browser)
        case .crop:
            return isValidCropUpdate(widget.crop, new.crop)
        case .map:
            return isValidMapUpdate(widget.map, new.map)
        case .scene:
            return isValidChange(widget.scene.sceneId, new.scene.sceneId) { sceneId in
                selectableScenes(widget: widget).contains { $0.id == sceneId }
            }
        case .qrCode, .image, .bingoCard:
            return true
        case .snapshot:
            return isValidChange(widget.snapshot.showtime, new.snapshot.showtime) {
                [3, 5, 10, 15, 30, 60, 120].contains($0)
            }
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
            return isValidSlideshowUpdate(widget.slideshow, new.slideshow)
        case .wheelOfLuck:
            return isValidWheelOfLuckUpdate(widget.wheelOfLuck, new.wheelOfLuck)
        case .videoSource:
            return isValidVideoSourceUpdate(widget.videoSource, new.videoSource)
        case .vTuber:
            return isValidVTuberUpdate(widget.vTuber, new.vTuber)
        case .pngTuber:
            return isValidCameraChange(widget.pngTuber.videoSource, new.pngTuber.videoSource)
                && isValidSensitivityUpdate(widget.pngTuber.sensitivity, new.pngTuber.sensitivity)
        case .pomodoroTimer:
            return isValidPomodoroTimerUpdate(widget.pomodoroTimer, new.pomodoroTimer)
        case .scoreboard:
            return isValidScoreboardUpdate(widget.scoreboard, new.scoreboard)
        case .alerts:
            return isValidAlertsUpdate(widget.alerts, new.alerts)
        }
    }

    func remoteControlApplyWidgetUpdate(widget: SettingsWidget,
                                        new: SettingsWidget) -> RemoteControlWidgetChanges
    {
        let changes = RemoteControlWidgetChanges(
            enabled: widget.enabled != new.enabled,
            camera: hasCameraChanged(widget: widget, new: new),
            formatString: widget.text.formatString != new.text.formatString
        )
        widget.name = new.name
        widget.enabled = new.enabled
        applyEffectsUpdate(widget: widget, new: new)
        switch widget.type {
        case .text:
            applyTextUpdate(widget.text, new.text)
        case .browser:
            applyBrowserUpdate(widget.browser, new.browser)
        case .crop:
            widget.crop.sourceWidgetId = new.crop.sourceWidgetId
            widget.crop.x = new.crop.x
            widget.crop.y = new.crop.y
            widget.crop.width = new.crop.width
            widget.crop.height = new.crop.height
        case .map:
            widget.map.northUp = new.map.northUp
            widget.map.size = new.map.size
            widget.map.delay = new.map.delay
        case .scene:
            widget.scene.sceneId = new.scene.sceneId
        case .qrCode:
            widget.qrCode.message = new.qrCode.message
        case .image:
            break
        case .snapshot:
            widget.snapshot.showtime = new.snapshot.showtime
        case .chat:
            applyChatUpdate(widget.chat, new.chat)
        case .chatEmoteCombo:
            widget.chatEmoteCombo.minimumCombo = new.chatEmoteCombo.minimumCombo
            widget.chatEmoteCombo.resetAfter = new.chatEmoteCombo.resetAfter
        case .slideshow:
            applySlideshowUpdate(widget.slideshow, new.slideshow)
        case .wheelOfLuck:
            applyWheelOfLuckUpdate(widget.wheelOfLuck, new.wheelOfLuck)
        case .bingoCard:
            applyBingoCardUpdate(widget.bingoCard, new.bingoCard)
        case .videoSource:
            applyVideoSourceUpdate(widget.videoSource, new.videoSource)
        case .vTuber:
            applyVTuberUpdate(widget.vTuber, new.vTuber)
        case .pngTuber:
            applyPngTuberUpdate(widget.pngTuber, new.pngTuber)
        case .pomodoroTimer:
            applyPomodoroTimerUpdate(widget.pomodoroTimer, new.pomodoroTimer)
        case .scoreboard:
            applyScoreboardUpdate(widget.scoreboard, new.scoreboard)
        case .alerts:
            applyAlertsUpdate(widget: widget, new: new.alerts)
        }
        return changes
    }

    func remoteControlWidgetUpdated(widget: SettingsWidget, changes: RemoteControlWidgetChanges) {
        if noReloadWidgetTypes.contains(widget.type) {
            if changes.enabled {
                sceneUpdated(attachCamera: isCaptureDeviceWidget(widget: widget))
            }
            switch widget.type {
            case .alerts:
                fixAlertMedias()
            case .wheelOfLuck:
                updateWheelOfLuckEffect(widget: widget)
            case .bingoCard:
                getBingoCardEffect(id: widget.id)?.setSettings(settings: widget.bingoCard)
            case .chat:
                getChatEffect(id: widget.id)?.setSettings(settings: widget.chat)
                updateWidgetOutlines()
            case .chatEmoteCombo:
                getChatEmoteComboEffect(id: widget.id)?.setSettings(settings: widget.chatEmoteCombo)
            case .pomodoroTimer:
                updateWidgetOutlines()
            default:
                break
            }
        } else {
            resetSelectedScene(changeScene: false,
                               attachCamera: changes.camera || isCaptureDeviceWidget(widget: widget))
            switch widget.type {
            case .text:
                if changes.formatString {
                    textWidgetTextChanged(widget: widget)
                }
            case .scoreboard:
                remoteControlScoreboardWidgetUpdated(widget: widget)
            default:
                break
            }
        }
    }

    func remoteControlIsValidSceneUpdate(scene: SettingsScene, new: SettingsScene) -> Bool {
        for sceneWidget in new.widgets {
            if let oldSceneWidget = scene.widgets.first(where: { $0.id == sceneWidget.id }) {
                guard oldSceneWidget.widgetId == sceneWidget.widgetId,
                      isValidLayoutChange(oldSceneWidget.layout, sceneWidget.layout)
                else {
                    return false
                }
            } else {
                guard findWidget(id: sceneWidget.widgetId) != nil,
                      isValidLayoutChange(SettingsWidgetLayout(), sceneWidget.layout)
                else {
                    return false
                }
            }
        }
        return isValidCameraChange(scene.videoSource, new.videoSource)
            && isValidChange(scene.videoSourceRotation, new.videoSourceRotation) {
                videoSourceRotations.contains($0)
            }
            && isValidChange(scene.videoStabilizationMode, new.videoStabilizationMode) {
                videoStabilizationModes.contains($0)
            }
            && isValidChange(scene.quickSwitchGroup, new.quickSwitchGroup) { group in
                group.map { (1 ... 4).contains($0) } ?? true
            }
            && isValidChange(scene.micId, new.micId) { micId in
                database.mics.mics.contains { $0.id == micId }
            }
    }

    func remoteControlApplySceneUpdate(scene: SettingsScene, new: SettingsScene) {
        let selected = getSelectedScene() === scene
        let overrideMicChanged = scene.overrideMic != new.overrideMic
        let quickSwitchGroupChanged = scene.quickSwitchGroup != new.quickSwitchGroup
        scene.name = new.name
        scene.enabled = new.enabled
        if cameraId(scene.videoSource) != cameraId(new.videoSource) {
            scene.updateCameraId(settingsCameraId: new.videoSource.toCameraId())
        }
        scene.videoSourceRotation = new.videoSourceRotation
        scene.mirror = new.mirror
        scene.overrideVideoStabilizationMode = new.overrideVideoStabilizationMode
        scene.videoStabilizationMode = new.videoStabilizationMode
        scene.fillFrame = new.fillFrame
        scene.quickSwitchGroup = new.quickSwitchGroup
        scene.overrideMic = new.overrideMic
        scene.micId = new.micId
        scene.backgroundColor = new.backgroundColor
        scene.backgroundColorColor = new.backgroundColor.color()
        scene.widgets = new.widgets.map { sceneWidget in
            let oldSceneWidget = scene.widgets.first { $0.id == sceneWidget.id }
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
        sceneSelector.objectWillChange.send()
        if quickSwitchGroupChanged, selected {
            resetSelectedScene(changeScene: false, attachCamera: true)
        }
        if overrideMicChanged {
            switchMicIfNeededAfterSceneSwitch()
        }
    }

    private func remoteControlScoreboardWidgetUpdated(widget: SettingsWidget) {
        let scoreboard = widget.scoreboard
        switch scoreboard.sport {
        case .generic:
            sendUpdateGenericScoreboardToWatch(id: widget.id, generic: scoreboard.generic)
        case .padel:
            sendUpdatePadelScoreboardToWatch(id: widget.id, padel: scoreboard.padel)
        default:
            break
        }
        remoteControlScoreboardUpdate(scoreboard: scoreboard)
        getScoreboardEffect(id: widget.id)?
            .update(
                scoreboard: scoreboard,
                config: getModularScoreboardConfig(scoreboard: scoreboard),
                players: database.scoreboardPlayers
            )
    }

    private func cameraId(_ videoSource: SettingsVideoSource) -> CameraId {
        getCameraId(settingsCameraId: videoSource.toCameraId())
    }

    private func isValidCameraChange(_ old: SettingsVideoSource, _ new: SettingsVideoSource) -> Bool {
        isValidChange(cameraId(old), cameraId(new)) { cameraId in
            videoSources.all().contains { $0.id == cameraId }
        }
    }

    private func hasCameraChanged(widget: SettingsWidget, new: SettingsWidget) -> Bool {
        switch widget.type {
        case .videoSource:
            cameraId(widget.videoSource.videoSource) != cameraId(new.videoSource.videoSource)
        case .vTuber:
            cameraId(widget.vTuber.videoSource) != cameraId(new.vTuber.videoSource)
        case .pngTuber:
            cameraId(widget.pngTuber.videoSource) != cameraId(new.pngTuber.videoSource)
        default:
            false
        }
    }

    private func isValidEffectsUpdate(widget: SettingsWidget, new: SettingsWidget) -> Bool {
        guard effectsWidgetTypes.contains(widget.type) else {
            return true
        }
        guard Set(new.effects.map(\.id)).count == new.effects.count else {
            return false
        }
        return new.effects.allSatisfy { effect in
            if let oldEffect = widget.effects.first(where: { $0.id == effect.id }) {
                return oldEffect.type == effect.type && isValidEffectUpdate(oldEffect, effect)
            }
            let defaultEffect = SettingsVideoEffect()
            defaultEffect.type = effect.type
            return isValidEffectUpdate(defaultEffect, effect)
        }
    }

    private func isValidEffectUpdate(_ old: SettingsVideoEffect, _ new: SettingsVideoEffect) -> Bool {
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

    private func applyEffectsUpdate(widget: SettingsWidget, new: SettingsWidget) {
        guard effectsWidgetTypes.contains(widget.type) else {
            return
        }
        widget.effects = new.effects.map { effect in
            guard let oldEffect = widget.effects.first(where: { $0.id == effect.id }) else {
                return effect
            }
            applyEffectUpdate(oldEffect, effect)
            return oldEffect
        }
    }

    private func applyEffectUpdate(_ effect: SettingsVideoEffect, _ new: SettingsVideoEffect) {
        effect.enabled = new.enabled
        switch effect.type {
        case .removeBackground:
            effect.removeBackground.from = new.removeBackground.from
            effect.removeBackground.fromColor = new.removeBackground.from.color()
            effect.removeBackground.to = new.removeBackground.to
            effect.removeBackground.toColor = new.removeBackground.to.color()
        case .shape:
            let shape = effect.shape
            shape.cornerRadius = new.shape.cornerRadius
            shape.borderWidth = new.shape.borderWidth
            shape.borderColor = new.shape.borderColor
            shape.borderColorColor = new.shape.borderColor.color()
            shape.cropEnabled = new.shape.cropEnabled
            shape.cropX = new.shape.cropX
            shape.cropY = new.shape.cropY
            shape.cropWidth = new.shape.cropWidth
            shape.cropHeight = new.shape.cropHeight
        case .dewarp360:
            effect.dewarp360.pan = new.dewarp360.pan
            effect.dewarp360.tilt = new.dewarp360.tilt
            effect.dewarp360.zoom = new.dewarp360.zoom
            effect.dewarp360.inverseFieldOfView = new.dewarp360.inverseFieldOfView
        case .anamorphicLens:
            effect.anamorphicLens.scale = new.anamorphicLens.scale
        case .lut:
            effect.lut.lut = new.lut.lut
        case .opacity:
            effect.opacity.opacity = new.opacity.opacity
        case .mask:
            let mask = effect.mask
            mask.points = new.mask.points
            mask.inverted = new.mask.inverted
            mask.tension = new.mask.tension
            mask.backgroundType = new.mask.backgroundType
            mask.backgroundColor = new.mask.backgroundColor
            mask.backgroundColorColor = new.mask.backgroundColor.color()
            mask.backgroundColor2 = new.mask.backgroundColor2
            mask.backgroundColorColor2 = new.mask.backgroundColor2.color()
        case .grayScale, .sepia, .whirlpool, .pinch:
            break
        }
    }

    private func isValidTextUpdate(_ old: SettingsWidgetText, _ new: SettingsWidgetText) -> Bool {
        isValidChange(old.fontSize, new.fontSize) { (10 ... 200).contains($0) }
            && isValidChange(old.width, new.width) { $0 > 0 && $0 < 4000 }
            && isValidChange(old.cornerRadius, new.cornerRadius) { $0 >= 0 && $0 < 1000 }
            && isValidChange(old.delay, new.delay) { (0 ... 10).contains($0) }
            && zip(old.timers, new.timers).allSatisfy { oldTimer, newTimer in
                isValidChange(oldTimer.delta, newTimer.delta) { [1, 2, 5, 15, 60].contains($0) }
            }
    }

    private func applyTextUpdate(_ text: SettingsWidgetText, _ new: SettingsWidgetText) {
        text.formatString = new.formatString
        text.backgroundColor = new.backgroundColor
        text.backgroundColorColor = new.backgroundColor.color()
        text.foregroundColor = new.foregroundColor
        text.foregroundColorColor = new.foregroundColor.color()
        text.fontSize = new.fontSize
        text.fontSizeFloat = Float(new.fontSize)
        text.font = new.font
        text.fontDesign = new.fontDesign
        text.fontWeight = new.fontWeight
        text.fontMonospacedDigits = new.fontMonospacedDigits
        text.horizontalAlignment = new.horizontalAlignment
        text.widthEnabled = new.widthEnabled
        text.width = new.width
        text.cornerRadius = new.cornerRadius
        text.delay = new.delay
        for (timer, newTimer) in zip(text.timers, new.timers) {
            timer.delta = newTimer.delta
        }
    }

    private func isValidBrowserUpdate(_ old: SettingsWidgetBrowser, _ new: SettingsWidgetBrowser) -> Bool {
        isValidChange(old.url, new.url) { isValidHttpUrl(url: $0.trim()) == nil }
            && isValidChange(old.width, new.width) { $0 > 0 && $0 < 4000 }
            && isValidChange(old.height, new.height) { $0 > 0 && $0 < 4000 }
            && isValidChange(old.baseFps, new.baseFps) { (1 ... 15).contains($0) }
    }

    private func applyBrowserUpdate(_ browser: SettingsWidgetBrowser, _ new: SettingsWidgetBrowser) {
        browser.url = new.url.trim()
        browser.styleSheet = new.styleSheet.trim()
        browser.width = new.width
        browser.height = new.height
        browser.localOnly = new.localOnly
        browser.mode = new.mode
        browser.baseFps = new.baseFps
        browser.moblinAccess = new.moblinAccess
        browser.speechToText = new.speechToText
    }

    private func isValidCropUpdate(_ old: SettingsWidgetCrop, _ new: SettingsWidgetCrop) -> Bool {
        isValidChange(old.sourceWidgetId, new.sourceWidgetId) { sourceWidgetId in
            database.widgets.contains { $0.id == sourceWidgetId && $0.type == .browser }
        }
            && isValidChange(old.x, new.x) { $0 >= 0 }
            && isValidChange(old.y, new.y) { $0 >= 0 }
            && isValidChange(old.width, new.width) { $0 > 0 }
            && isValidChange(old.height, new.height) { $0 > 0 }
    }

    private func isValidMapUpdate(_ old: SettingsWidgetMap, _ new: SettingsWidgetMap) -> Bool {
        isValidChange(old.size, new.size) { (500 ... 10000).contains($0) }
            && isValidChange(old.delay, new.delay) { (0 ... 10).contains($0) }
    }

    private func isValidChatUpdate(_ old: SettingsWidgetChat, _ new: SettingsWidgetChat) -> Bool {
        isValidChange(old.fontSize, new.fontSize) { (10 ... 50).contains($0) }
            && isValidChange(old.maximumNumberOfMessages, new.maximumNumberOfMessages) {
                (1 ... 5).contains($0)
            }
            && isValidChange(old.height, new.height) { (0.1 ... 1).contains($0) }
    }

    private func applyChatUpdate(_ chat: SettingsWidgetChat, _ new: SettingsWidgetChat) {
        chat.fontSize = new.fontSize
        chat.font = new.font
        chat.usernameColor = new.usernameColor
        chat.usernameColorColor = new.usernameColor.color()
        chat.messageColor = new.messageColor
        chat.messageColorColor = new.messageColor.color()
        chat.backgroundColor = new.backgroundColor
        chat.backgroundColorColor = new.backgroundColor.color()
        chat.backgroundColorEnabled = new.backgroundColorEnabled
        chat.shadowColor = new.shadowColor
        chat.shadowColorColor = new.shadowColor.color()
        chat.shadowColorEnabled = new.shadowColorEnabled
        chat.boldUsername = new.boldUsername
        chat.boldMessage = new.boldMessage
        chat.badges = new.badges
        chat.displayStyle = new.displayStyle
        chat.sharedChatIcons = new.sharedChatIcons
        chat.height = new.height
        chat.maximumNumberOfMessages = new.maximumNumberOfMessages
    }

    private func isValidSlideshowUpdate(_ old: SettingsWidgetSlideshow,
                                        _ new: SettingsWidgetSlideshow) -> Bool
    {
        new.slides.allSatisfy { slide in
            let oldSlide = old.slides.first { $0.id == slide.id } ?? SettingsWidgetSlideshowSlide()
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

    private func applySlideshowUpdate(_ slideshow: SettingsWidgetSlideshow, _ new: SettingsWidgetSlideshow) {
        slideshow.slides = new.slides.map { slide in
            guard let oldSlide = slideshow.slides.first(where: { $0.id == slide.id }) else {
                return slide
            }
            oldSlide.widgetId = slide.widgetId
            oldSlide.time = slide.time
            return oldSlide
        }
    }

    private func isValidWheelOfLuckUpdate(_ old: SettingsWidgetWheelOfLuck,
                                          _ new: SettingsWidgetWheelOfLuck) -> Bool
    {
        guard !new.options.isEmpty else {
            return false
        }
        return new.options.allSatisfy { option in
            let oldOption = old.options.first { $0.id == option.id } ?? SettingsWidgetWheelOfLuckOption()
            return isValidChange(oldOption.weight, option.weight) { wheelOfLuckOptionWeights.contains($0) }
                && isValidChange(oldOption.function, option.function) {
                    ![.zoomIn, .zoomOut, .gimbalUp, .gimbalDown, .gimbalLeft, .gimbalRight, .gimbalPreset]
                        .contains($0)
                }
        }
    }

    private func applyWheelOfLuckUpdate(_ wheelOfLuck: SettingsWidgetWheelOfLuck,
                                        _ new: SettingsWidgetWheelOfLuck)
    {
        wheelOfLuck.advanced = new.advanced
        wheelOfLuck.onlyShowWhenSpinning = new.onlyShowWhenSpinning
        wheelOfLuck.options = new.options.map { option in
            guard let oldOption = wheelOfLuck.options.first(where: { $0.id == option.id }) else {
                return option
            }
            oldOption.text = option.text
            oldOption.weight = option.weight
            oldOption.function = option.function
            oldOption.functionData = option.functionData
            return oldOption
        }
        wheelOfLuck.updateText()
        wheelOfLuck.updateTotalWeight()
    }

    private func applyBingoCardUpdate(_ bingoCard: SettingsWidgetBingoCard, _ new: SettingsWidgetBingoCard) {
        bingoCard.backgroundColor = new.backgroundColor
        bingoCard.backgroundColorColor = new.backgroundColor.color()
        bingoCard.foregroundColor = new.foregroundColor
        bingoCard.foregroundColorColor = new.foregroundColor.color()
        bingoCard.squares = new.squares
        bingoCard.squaresText = new.squaresText
    }

    private func isValidVideoSourceUpdate(_ old: SettingsWidgetVideoSource,
                                          _ new: SettingsWidgetVideoSource) -> Bool
    {
        isValidCameraChange(old.videoSource, new.videoSource)
            && isValidChange(old.rotation, new.rotation) { videoSourceRotations.contains($0) }
            && isValidChange(old.trackFaceZoom, new.trackFaceZoom) { (0 ... 1).contains($0) }
    }

    private func applyVideoSourceUpdate(_ videoSource: SettingsWidgetVideoSource,
                                        _ new: SettingsWidgetVideoSource)
    {
        if cameraId(videoSource.videoSource) != cameraId(new.videoSource) {
            videoSource.updateCameraId(settingsCameraId: new.videoSource.toCameraId())
        }
        videoSource.rotation = new.rotation
        videoSource.mirror = new.mirror
        videoSource.trackFaceEnabled = new.trackFaceEnabled
        videoSource.trackFaceZoom = new.trackFaceZoom
    }

    private func isValidSensitivityUpdate(_ old: SettingsSensitivity, _ new: SettingsSensitivity) -> Bool {
        isValidChange(old.mouth, new.mouth) { (0.05 ... 3).contains($0) }
            && isValidChange(old.eyes, new.eyes) { (0.05 ... 5).contains($0) }
    }

    private func isValidVTuberUpdate(_ old: SettingsWidgetVTuber, _ new: SettingsWidgetVTuber) -> Bool {
        isValidCameraChange(old.videoSource, new.videoSource)
            && isValidChange(old.cameraPositionY, new.cameraPositionY) { (1 ... 2).contains($0) }
            && isValidChange(old.cameraFieldOfView, new.cameraFieldOfView) { (10 ... 30).contains($0) }
            && isValidChange(old.armsAngle, new.armsAngle) { (20 ... 90).contains($0) }
            && isValidSensitivityUpdate(old.sensitivity, new.sensitivity)
    }

    private func applyVTuberUpdate(_ vTuber: SettingsWidgetVTuber, _ new: SettingsWidgetVTuber) {
        if cameraId(vTuber.videoSource) != cameraId(new.videoSource) {
            vTuber.updateCameraId(settingsCameraId: new.videoSource.toCameraId())
        }
        vTuber.cameraPositionY = new.cameraPositionY
        vTuber.cameraFieldOfView = new.cameraFieldOfView
        vTuber.mirror = new.mirror
        vTuber.sensitivity = new.sensitivity
        vTuber.armsAngle = new.armsAngle
    }

    private func applyPngTuberUpdate(_ pngTuber: SettingsWidgetPngTuber, _ new: SettingsWidgetPngTuber) {
        if cameraId(pngTuber.videoSource) != cameraId(new.videoSource) {
            pngTuber.updateCameraId(settingsCameraId: new.videoSource.toCameraId())
        }
        pngTuber.mirror = new.mirror
        pngTuber.sensitivity = new.sensitivity
    }

    private func isValidAlertSoundId(_ soundId: UUID?) -> Bool {
        soundId.map { soundId in getAllAlertSounds().contains { $0.id == soundId } } ?? true
    }

    private func isValidPomodoroTimerUpdate(_ old: SettingsWidgetPomodoroTimer,
                                            _ new: SettingsWidgetPomodoroTimer) -> Bool
    {
        isValidChange(old.focusDuration, new.focusDuration) {
            [1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120].contains($0)
        }
            && isValidChange(old.breakDuration, new.breakDuration) {
                [1, 2, 3, 5, 7, 10, 15, 20, 25, 30].contains($0)
            }
            && isValidChange(old.width, new.width) { (1 ... 5).contains($0) }
            && isValidChange(old.focusToBreakSoundId, new.focusToBreakSoundId) { isValidAlertSoundId($0) }
            && isValidChange(old.breakToFocusSoundId, new.breakToFocusSoundId) { isValidAlertSoundId($0) }
    }

    private func applyPomodoroTimerUpdate(_ pomodoroTimer: SettingsWidgetPomodoroTimer,
                                          _ new: SettingsWidgetPomodoroTimer)
    {
        if pomodoroTimer.focusDuration != new.focusDuration {
            pomodoroTimer.focusDuration = new.focusDuration
            if pomodoroTimer.phase == .focus, !pomodoroTimer.isRunning {
                pomodoroTimer.secondsRemaining = pomodoroTimer.focusDuration * 60
            }
        }
        if pomodoroTimer.breakDuration != new.breakDuration {
            pomodoroTimer.breakDuration = new.breakDuration
            if pomodoroTimer.phase == .shortBreak, !pomodoroTimer.isRunning {
                pomodoroTimer.secondsRemaining = pomodoroTimer.breakDuration * 60
            }
        }
        pomodoroTimer.width = new.width
        pomodoroTimer.focusName = new.focusName
        pomodoroTimer.breakName = new.breakName
        pomodoroTimer.focusIcon = new.focusIcon
        pomodoroTimer.breakIcon = new.breakIcon
        pomodoroTimer.backgroundColor = new.backgroundColor
        pomodoroTimer.backgroundColorColor = new.backgroundColor.color()
        pomodoroTimer.foregroundColor = new.foregroundColor
        pomodoroTimer.foregroundColorColor = new.foregroundColor.color()
        pomodoroTimer.focusColor = new.focusColor
        pomodoroTimer.focusColorColor = new.focusColor.color()
        pomodoroTimer.breakColor = new.breakColor
        pomodoroTimer.breakColorColor = new.breakColor.color()
        pomodoroTimer.focusToBreakSoundId = new.focusToBreakSoundId
        pomodoroTimer.breakToFocusSoundId = new.breakToFocusSoundId
        pomodoroTimer.focusToBreakChatMessage = new.focusToBreakChatMessage
        pomodoroTimer.breakToFocusChatMessage = new.breakToFocusChatMessage
    }

    private func isValidScoreboardUpdate(_ old: SettingsWidgetScoreboard,
                                         _ new: SettingsWidgetScoreboard) -> Bool
    {
        let isValidPlayerId = { (playerId: UUID) in
            self.database.scoreboardPlayers.contains { $0.id == playerId }
        }
        let oldPadel = old.padel
        let newPadel = new.padel
        let oldGolf = old.golf
        let newGolf = new.golf
        let oldModular = old.modular
        let newModular = new.modular
        return isValidChange(oldPadel.homePlayer1, newPadel.homePlayer1, isValidPlayerId)
            && isValidChange(oldPadel.homePlayer2, newPadel.homePlayer2, isValidPlayerId)
            && isValidChange(oldPadel.awayPlayer1, newPadel.awayPlayer1, isValidPlayerId)
            && isValidChange(oldPadel.awayPlayer2, newPadel.awayPlayer2, isValidPlayerId)
            &&
            isValidChange(old.generic.clock.maximum, new.generic.clock.maximum) {
                (1 ... 180).contains($0)
            }
            && isValidChange(oldGolf.numberOfHoles, newGolf.numberOfHoles) { [9, 18].contains($0) }
            && isValidChange(oldGolf.pars, newGolf.pars) { $0.allSatisfy { (1 ... 9).contains($0) } }
            && isValidChange(oldGolf.players.count, newGolf.players.count) { $0 <= 4 }
            && isValidChange(oldModular.clock.maximum, newModular.clock.maximum) { (1 ... 180).contains($0) }
            && isValidChange(oldModular.width, newModular.width) { (100 ... 1000).contains($0) }
            && isValidChange(oldModular.rowHeight, newModular.rowHeight) { (10 ... 150).contains($0) }
    }

    private func applyScoreboardClockUpdate(_ clock: SettingsWidgetScoreboardClock,
                                            _ new: SettingsWidgetScoreboardClock)
    {
        guard clock.maximum != new.maximum || clock.direction != new.direction else {
            return
        }
        clock.maximum = new.maximum
        clock.direction = new.direction
        clock.reset()
    }

    private func applyScoreboardTeamUpdate(_ team: SettingsWidgetModularScoreboardTeam,
                                           _ new: SettingsWidgetModularScoreboardTeam)
    {
        team.name = new.name
        team.textColor = new.textColor
        team.backgroundColor = new.backgroundColor
        team.loadColors()
    }

    private func applyScoreboardUpdate(
        _ scoreboard: SettingsWidgetScoreboard,
        _ new: SettingsWidgetScoreboard
    ) {
        if scoreboard.sport != new.sport {
            scoreboard.sport = new.sport
            scoreboard.modular.config = nil
        }
        scoreboard.textColor = new.textColor
        scoreboard.primaryBackgroundColor = new.primaryBackgroundColor
        scoreboard.secondaryBackgroundColor = new.secondaryBackgroundColor
        scoreboard.loadColors()
        let padel = scoreboard.padel
        padel.type = new.padel.type
        padel.homePlayer1 = new.padel.homePlayer1
        padel.homePlayer2 = new.padel.homePlayer2
        padel.awayPlayer1 = new.padel.awayPlayer1
        padel.awayPlayer2 = new.padel.awayPlayer2
        let generic = scoreboard.generic
        generic.home = new.generic.home
        generic.away = new.generic.away
        generic.title = new.generic.title
        applyScoreboardClockUpdate(generic.clock, new.generic.clock)
        let golf = scoreboard.golf
        golf.title = new.golf.title
        if golf.numberOfHoles != new.golf.numberOfHoles {
            golf.numberOfHoles = new.golf.numberOfHoles
            golf.currentHole = 0
        }
        golf.setPars(new.golf.pars)
        golf.players = new.golf.players.map { player in
            if let oldPlayer = golf.players.first(where: { $0.id == player.id }) {
                oldPlayer.name = player.name
                return oldPlayer
            }
            let newPlayer = SettingsWidgetGolfScoreboardPlayer(name: player.name)
            newPlayer.id = player.id
            return newPlayer
        }
        golf.showPars = new.golf.showPars
        let modular = scoreboard.modular
        applyScoreboardTeamUpdate(modular.home, new.modular.home)
        applyScoreboardTeamUpdate(modular.away, new.modular.away)
        applyScoreboardClockUpdate(modular.clock, new.modular.clock)
        modular.layout = new.modular.layout
        modular.width = new.modular.width
        modular.rowHeight = new.modular.rowHeight
        modular.isBold = new.modular.isBold
        modular.showTitle = new.modular.showTitle
        modular.showMoreStats = new.modular.showMoreStats
        modular.showGlobalStatsBlock = new.modular.showGlobalStatsBlock
        modular.showClock = new.modular.showClock
    }

    private func isValidAlertsUpdate(_ old: SettingsWidgetAlerts, _ new: SettingsWidgetAlerts) -> Bool {
        let oldAlerts = allAlerts(old)
        return allAlerts(new).allSatisfy { alert in
            guard let oldAlert = oldAlerts.first(where: { $0.id == alert.id }) else {
                return isValidAlertUpdate(SettingsWidgetAlertsAlert(), alert, checkMedia: false)
            }
            return isValidAlertUpdate(oldAlert, alert, checkMedia: true)
        }
            && isValidChange(old.aiEnabled, new.aiEnabled) { !$0 || new.ai.isConfigured() }
            && isValidChange(old.ai.baseUrl, new.ai.baseUrl) { isValidHttpUrl(url: $0) == nil }
    }

    private func isValidAlertUpdate(_ old: SettingsWidgetAlertsAlert,
                                    _ new: SettingsWidgetAlertsAlert,
                                    checkMedia: Bool) -> Bool
    {
        if checkMedia {
            guard isValidChange(old.imageId, new.imageId, { imageId in
                getAllAlertImages().contains { $0.id == imageId }
            }), isValidChange(old.soundId, new.soundId, { soundId in
                getAllAlertSounds().contains { $0.id == soundId }
            }) else {
                return false
            }
        }
        return isValidChange(old.imageLoopCount, new.imageLoopCount) { (1 ... 10).contains($0) }
            && isValidChange(old.fontSize, new.fontSize) { (10 ... 80).contains($0) }
            && isValidChange(old.textToSpeechDelay, new.textToSpeechDelay) { (0 ... 5).contains($0) }
    }

    private func applyAlertsUpdate(widget: SettingsWidget, new: SettingsWidgetAlerts) {
        let alerts = widget.alerts
        let oldAlerts = allAlerts(alerts)
        for alert in allAlerts(new) {
            if let oldAlert = oldAlerts.first(where: { $0.id == alert.id }) {
                alert.videoName = oldAlert.videoName
            } else {
                alert.videoName = ""
                fixAlert(alert: alert)
            }
        }
        for command in new.chatBot.commands {
            command.name = command.name.lowercased().removeAllWhitespaces()
            command.imageType = alerts.chatBot.commands.first { $0.id == command.id }?.imageType ?? .file
        }
        new.twitch.cheers = alerts.twitch.cheers
        new.twitch.redemptions = alerts.twitch.redemptions
        new.quickButton = alerts.quickButton
        new.needsSubtitles = alerts.needsSubtitles
        new.ttsMonster = alerts.ttsMonster
        widget.alerts = new
    }
}
