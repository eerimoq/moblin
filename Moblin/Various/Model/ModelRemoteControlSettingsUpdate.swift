import Foundation

struct ChangeTracker {
    private(set) var changed = false

    @discardableResult
    mutating func apply<T: Equatable>(_ value: inout T, _ new: T) -> Bool {
        guard value != new else {
            return false
        }
        value = new
        changed = true
        return true
    }

    mutating func applyItems<T: Identifiable>(_ items: inout [T], _ newItems: [T]) {
        if items.map(\.id) != newItems.map(\.id) {
            changed = true
        }
        items = newItems
    }
}

extension Model {
    func remoteControlMakeWidget(widget: SettingsWidget) -> SettingsWidget? {
        if widget.name.isEmpty {
            widget.name = makeUniqueName(name: SettingsWidget.baseName, existingNames: database.widgets)
        }
        let newWidget = SettingsWidget(name: widget.name)
        newWidget.id = widget.id
        newWidget.type = widget.type
        guard remoteControlApplyWidgetUpdate(widget: newWidget, new: widget, creating: true) else {
            return nil
        }
        return newWidget
    }

    func remoteControlApplyWidgetUpdate(widget: SettingsWidget, new: SettingsWidget, creating: Bool) -> Bool {
        guard isValidRemoteControlWidgetUpdate(widget: widget,
                                               new: new,
                                               creating: creating,
                                               editableTextTimers: remoteControlEditableTextTimers(
                                                   widget: widget,
                                                   new: new
                                               ),
                                               database: database,
                                               cameras: remoteControlCameras())
        else {
            return false
        }
        applyWidgetTypeUpdate(widget: widget, new: new, creating: creating)
        widget.name = new.name
        if widget.enabled != new.enabled {
            widget.enabled = new.enabled
            if !creating {
                widgetEnabledChanged(widget: widget)
            }
        }
        return true
    }

    private func remoteControlEditableTextTimers(widget: SettingsWidget, new: SettingsWidget) -> Int {
        guard widget.type == .text, !getTextEffects(id: widget.id).isEmpty else {
            return 0
        }
        return loadTextFormat(format: new.text.formatString).count(where: { $0 == .timer })
    }

    func remoteControlCameras() -> RemoteControlCameras {
        RemoteControlCameras(ids: Set(videoSources.all().map(\.id)), cameraId: { self.cameraId($0) })
    }

    private func applyWidgetTypeUpdate(widget: SettingsWidget, new: SettingsWidget, creating: Bool) {
        switch widget.type {
        case .text:
            updateTextWidget(widget, new, creating)
        case .browser:
            updateBrowserWidget(widget, new, creating)
        case .crop:
            updateCropWidget(widget, new, creating)
        case .map:
            updateMapWidget(widget, new, creating)
        case .scene:
            updateSceneWidget(widget, new, creating)
        case .qrCode:
            updateQrCodeWidget(widget, new, creating)
        case .image:
            updateImageWidget(widget, new, creating)
        case .snapshot:
            updateSnapshotWidget(widget, new, creating)
        case .chat:
            updateChatWidget(widget, new, creating)
        case .chatEmoteCombo:
            updateChatEmoteComboWidget(widget, new, creating)
        case .slideshow:
            updateSlideshowWidget(widget, new, creating)
        case .wheelOfLuck:
            updateWheelOfLuckWidget(widget, new, creating)
        case .bingoCard:
            updateBingoCardWidget(widget, new, creating)
        case .videoSource:
            updateVideoSourceWidget(widget, new, creating)
        case .vTuber:
            updateVTuberWidget(widget, new, creating)
        case .pngTuber:
            updatePngTuberWidget(widget, new, creating)
        case .pomodoroTimer:
            updatePomodoroTimerWidget(widget, new, creating)
        case .scoreboard:
            updateScoreboardWidget(widget, new, creating)
        case .alerts:
            updateAlertsWidget(widget, new, creating)
        }
    }

    private func updateTextWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let text = widget.text
        let newText = new.text
        let formatChanged = text.formatString != newText.formatString
        text.formatString = newText.formatString
        var changes = ChangeTracker()
        let backgroundColorChanged = changes.apply(&text.backgroundColor, newText.backgroundColor)
        if backgroundColorChanged {
            text.backgroundColorColor = text.backgroundColor.color()
        }
        let foregroundColorChanged = changes.apply(&text.foregroundColor, newText.foregroundColor)
        if foregroundColorChanged {
            text.foregroundColorColor = text.foregroundColor.color()
        }
        let fontSizeChanged = changes.apply(&text.fontSize, newText.fontSize)
        if fontSizeChanged {
            text.fontSizeFloat = Float(text.fontSize)
        }
        let fontChanged = changes.apply(&text.font, newText.font)
        let fontDesignChanged = changes.apply(&text.fontDesign, newText.fontDesign)
        let fontWeightChanged = changes.apply(&text.fontWeight, newText.fontWeight)
        let fontMonospacedDigitsChanged = changes.apply(&text.fontMonospacedDigits,
                                                        newText.fontMonospacedDigits)
        var layout = ChangeTracker()
        layout.apply(&text.horizontalAlignment, newText.horizontalAlignment)
        layout.apply(&text.widthEnabled, newText.widthEnabled)
        layout.apply(&text.width, newText.width)
        layout.apply(&text.cornerRadius, newText.cornerRadius)
        let delayChanged = text.delay != newText.delay
        text.delay = newText.delay
        guard !creating else {
            return
        }
        if delayChanged {
            resetSelectedScene(changeScene: false)
        }
        if backgroundColorChanged {
            textWidgetBackgroundColorChanged(widget: widget)
        }
        if foregroundColorChanged {
            textWidgetForegroundColorChanged(widget: widget)
        }
        if fontSizeChanged {
            textWidgetFontSizeChanged(widget: widget)
        }
        if fontChanged {
            textWidgetFontChanged(widget: widget)
        }
        if fontDesignChanged {
            textWidgetFontDesignChanged(widget: widget)
        }
        if fontWeightChanged {
            textWidgetFontWeightChanged(widget: widget)
        }
        if fontMonospacedDigitsChanged {
            textWidgetFontMonospacedDigitsChanged(widget: widget)
        }
        if layout.changed {
            textWidgetLayoutChanged(widget: widget)
        }
        if formatChanged {
            textWidgetTextChanged(widget: widget)
        }
        for (timer, newTimer) in zip(text.timers, newText.timers) {
            timer.delta = newTimer.delta
        }
    }

    private func updateBrowserWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let browser = widget.browser
        let newBrowser = new.browser
        var changes = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&browser.url, newBrowser.url.trim())
        changes.apply(&browser.styleSheet, newBrowser.styleSheet.trim())
        changes.apply(&browser.width, newBrowser.width)
        changes.apply(&browser.height, newBrowser.height)
        changes.apply(&browser.localOnly, newBrowser.localOnly)
        changes.apply(&browser.mode, newBrowser.mode)
        changes.apply(&browser.baseFps, newBrowser.baseFps)
        changes.apply(&browser.moblinAccess, newBrowser.moblinAccess)
        changes.apply(&browser.speechToText, newBrowser.speechToText)
        if changes.changed, !creating {
            resetSelectedScene(changeScene: false)
        }
    }

    private func updateCropWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let crop = widget.crop
        let newCrop = new.crop
        var changes = ChangeTracker()
        changes.apply(&crop.sourceWidgetId, newCrop.sourceWidgetId)
        changes.apply(&crop.x, newCrop.x)
        changes.apply(&crop.y, newCrop.y)
        changes.apply(&crop.width, newCrop.width)
        changes.apply(&crop.height, newCrop.height)
        if changes.changed, !creating {
            resetSelectedScene(changeScene: false)
        }
    }

    private func updateMapWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let map = widget.map
        let newMap = new.map
        var changes = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&map.northUp, newMap.northUp)
        changes.apply(&map.size, newMap.size)
        changes.apply(&map.delay, newMap.delay)
        if changes.changed, !creating {
            resetSelectedScene(changeScene: false)
        }
    }

    private func updateSceneWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        var changes = ChangeTracker()
        changes.apply(&widget.scene.sceneId, new.scene.sceneId)
        if changes.changed, !creating {
            resetSelectedScene(changeScene: false)
        }
    }

    private func updateQrCodeWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        var changes = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&widget.qrCode.message, new.qrCode.message)
        if changes.changed, !creating {
            resetSelectedScene(changeScene: false)
        }
    }

    private func updateImageWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        var changes = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        if changes.changed, !creating {
            resetSelectedScene(changeScene: false)
        }
    }

    private func updateSnapshotWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        var effects = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &effects)
        var settings = ChangeTracker()
        settings.apply(&widget.snapshot.showtime, new.snapshot.showtime)
        guard !creating else {
            return
        }
        if effects.changed {
            resetSelectedScene(changeScene: false)
        }
        if settings.changed {
            snapshotWidgetShowtimeChanged(widget: widget)
        }
    }

    private func updateChatWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let chat = widget.chat
        let newChat = new.chat
        var changes = ChangeTracker()
        changes.apply(&chat.fontSize, newChat.fontSize)
        changes.apply(&chat.font, newChat.font)
        if changes.apply(&chat.usernameColor, newChat.usernameColor) {
            chat.usernameColorColor = chat.usernameColor.color()
        }
        if changes.apply(&chat.messageColor, newChat.messageColor) {
            chat.messageColorColor = chat.messageColor.color()
        }
        if changes.apply(&chat.backgroundColor, newChat.backgroundColor) {
            chat.backgroundColorColor = chat.backgroundColor.color()
        }
        changes.apply(&chat.backgroundColorEnabled, newChat.backgroundColorEnabled)
        if changes.apply(&chat.shadowColor, newChat.shadowColor) {
            chat.shadowColorColor = chat.shadowColor.color()
        }
        changes.apply(&chat.shadowColorEnabled, newChat.shadowColorEnabled)
        changes.apply(&chat.boldUsername, newChat.boldUsername)
        changes.apply(&chat.boldMessage, newChat.boldMessage)
        changes.apply(&chat.badges, newChat.badges)
        changes.apply(&chat.displayStyle, newChat.displayStyle)
        changes.apply(&chat.sharedChatIcons, newChat.sharedChatIcons)
        changes.apply(&chat.height, newChat.height)
        changes.apply(&chat.maximumNumberOfMessages, newChat.maximumNumberOfMessages)
        if changes.changed, !creating {
            chatWidgetSettingsChanged(widget: widget)
        }
    }

    private func updateChatEmoteComboWidget(
        _ widget: SettingsWidget,
        _ new: SettingsWidget,
        _ creating: Bool
    ) {
        let chatEmoteCombo = widget.chatEmoteCombo
        let newChatEmoteCombo = new.chatEmoteCombo
        var changes = ChangeTracker()
        changes.apply(&chatEmoteCombo.minimumCombo, newChatEmoteCombo.minimumCombo)
        changes.apply(&chatEmoteCombo.resetAfter, newChatEmoteCombo.resetAfter)
        if changes.changed, !creating {
            chatEmoteComboWidgetSettingsChanged(widget: widget)
        }
    }

    private func updateSlideshowWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let slideshow = widget.slideshow
        var changes = ChangeTracker()
        let slides = new.slideshow.slides.map { slide in
            guard let oldSlide = slideshow.slides.first(where: { $0.id == slide.id }) else {
                return slide
            }
            changes.apply(&oldSlide.widgetId, slide.widgetId)
            changes.apply(&oldSlide.time, slide.time)
            return oldSlide
        }
        changes.applyItems(&slideshow.slides, slides)
        if changes.changed, !creating {
            resetSelectedScene(changeScene: false, attachCamera: false)
        }
    }

    private func updateWheelOfLuckWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let wheelOfLuck = widget.wheelOfLuck
        let newWheelOfLuck = new.wheelOfLuck
        var changes = ChangeTracker()
        wheelOfLuck.advanced = newWheelOfLuck.advanced
        changes.apply(&wheelOfLuck.onlyShowWhenSpinning, newWheelOfLuck.onlyShowWhenSpinning)
        let options = newWheelOfLuck.options.map { option in
            guard let oldOption = wheelOfLuck.options.first(where: { $0.id == option.id }) else {
                return option
            }
            changes.apply(&oldOption.text, option.text)
            changes.apply(&oldOption.weight, option.weight)
            oldOption.function = option.function
            oldOption.functionData = option.functionData
            return oldOption
        }
        changes.applyItems(&wheelOfLuck.options, options)
        wheelOfLuck.updateText()
        wheelOfLuck.updateTotalWeight()
        if changes.changed, !creating {
            updateWheelOfLuckEffect(widget: widget)
        }
    }

    private func updateBingoCardWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let bingoCard = widget.bingoCard
        let newBingoCard = new.bingoCard
        var changes = ChangeTracker()
        if changes.apply(&bingoCard.backgroundColor, newBingoCard.backgroundColor) {
            bingoCard.backgroundColorColor = bingoCard.backgroundColor.color()
        }
        if changes.apply(&bingoCard.foregroundColor, newBingoCard.foregroundColor) {
            bingoCard.foregroundColorColor = bingoCard.foregroundColor.color()
        }
        changes.apply(&bingoCard.squares, newBingoCard.squares)
        changes.apply(&bingoCard.squaresText, newBingoCard.squaresText)
        if changes.changed, !creating {
            bingoCardWidgetSettingsChanged(widget: widget)
        }
    }

    private func updateVideoSourceWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let videoSource = widget.videoSource
        let newVideoSource = new.videoSource
        var effects = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &effects)
        let cameraChanged = cameraId(videoSource.videoSource) != cameraId(newVideoSource.videoSource)
        let settingsCameraId = newVideoSource.videoSource.toCameraId()
        if cameraChanged {
            videoSource.updateCameraId(settingsCameraId: settingsCameraId)
        }
        var settings = ChangeTracker()
        settings.apply(&videoSource.rotation, newVideoSource.rotation)
        settings.apply(&videoSource.mirror, newVideoSource.mirror)
        settings.apply(&videoSource.trackFaceEnabled, newVideoSource.trackFaceEnabled)
        settings.apply(&videoSource.trackFaceZoom, newVideoSource.trackFaceZoom)
        guard !creating else {
            return
        }
        if effects.changed {
            resetSelectedScene(changeScene: false)
        } else if cameraChanged {
            videoSourceWidgetSetCamera(widget: widget, settingsCameraId: settingsCameraId)
        }
        if settings.changed {
            videoSourceWidgetSettingsChanged(widget: widget)
        }
    }

    private func updateVTuberWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let vTuber = widget.vTuber
        let newVTuber = new.vTuber
        let cameraChanged = cameraId(vTuber.videoSource) != cameraId(newVTuber.videoSource)
        let settingsCameraId = newVTuber.videoSource.toCameraId()
        if cameraChanged {
            vTuber.updateCameraId(settingsCameraId: settingsCameraId)
        }
        var settings = ChangeTracker()
        settings.apply(&vTuber.cameraPositionY, newVTuber.cameraPositionY)
        settings.apply(&vTuber.cameraFieldOfView, newVTuber.cameraFieldOfView)
        settings.apply(&vTuber.mirror, newVTuber.mirror)
        settings.apply(&vTuber.sensitivity, newVTuber.sensitivity)
        settings.apply(&vTuber.armsAngle, newVTuber.armsAngle)
        guard !creating else {
            return
        }
        if cameraChanged {
            vTuberWidgetSetCamera(widget: widget, settingsCameraId: settingsCameraId)
        }
        if settings.changed {
            vTuberWidgetSettingsChanged(widget: widget)
        }
    }

    private func updatePngTuberWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let pngTuber = widget.pngTuber
        let newPngTuber = new.pngTuber
        let cameraChanged = cameraId(pngTuber.videoSource) != cameraId(newPngTuber.videoSource)
        let settingsCameraId = newPngTuber.videoSource.toCameraId()
        if cameraChanged {
            pngTuber.updateCameraId(settingsCameraId: settingsCameraId)
        }
        var settings = ChangeTracker()
        settings.apply(&pngTuber.mirror, newPngTuber.mirror)
        settings.apply(&pngTuber.sensitivity, newPngTuber.sensitivity)
        guard !creating else {
            return
        }
        if cameraChanged {
            pngTuberWidgetSetCamera(widget: widget, settingsCameraId: settingsCameraId)
        }
        if settings.changed {
            pngTuberWidgetSettingsChanged(widget: widget)
        }
    }

    private func updatePomodoroTimerWidget(_ widget: SettingsWidget, _ new: SettingsWidget,
                                           _ creating: Bool)
    {
        let pomodoroTimer = widget.pomodoroTimer
        let newPomodoroTimer = new.pomodoroTimer
        var changes = ChangeTracker()
        if changes.apply(&pomodoroTimer.focusDuration, newPomodoroTimer.focusDuration) {
            pomodoroTimer.focusDurationChanged()
        }
        if changes.apply(&pomodoroTimer.breakDuration, newPomodoroTimer.breakDuration) {
            pomodoroTimer.breakDurationChanged()
        }
        let widthChanged = changes.apply(&pomodoroTimer.width, newPomodoroTimer.width)
        pomodoroTimer.focusName = newPomodoroTimer.focusName
        pomodoroTimer.breakName = newPomodoroTimer.breakName
        pomodoroTimer.focusIcon = newPomodoroTimer.focusIcon
        pomodoroTimer.breakIcon = newPomodoroTimer.breakIcon
        pomodoroTimer.backgroundColor = newPomodoroTimer.backgroundColor
        pomodoroTimer.backgroundColorColor = newPomodoroTimer.backgroundColor.color()
        pomodoroTimer.foregroundColor = newPomodoroTimer.foregroundColor
        pomodoroTimer.foregroundColorColor = newPomodoroTimer.foregroundColor.color()
        pomodoroTimer.focusColor = newPomodoroTimer.focusColor
        pomodoroTimer.focusColorColor = newPomodoroTimer.focusColor.color()
        pomodoroTimer.breakColor = newPomodoroTimer.breakColor
        pomodoroTimer.breakColorColor = newPomodoroTimer.breakColor.color()
        pomodoroTimer.focusToBreakSoundId = newPomodoroTimer.focusToBreakSoundId
        pomodoroTimer.breakToFocusSoundId = newPomodoroTimer.breakToFocusSoundId
        pomodoroTimer.focusToBreakChatMessage = newPomodoroTimer.focusToBreakChatMessage
        pomodoroTimer.breakToFocusChatMessage = newPomodoroTimer.breakToFocusChatMessage
        if widthChanged, !creating {
            updateWidgetOutlines()
        }
    }

    private func updateScoreboardWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let scoreboard = widget.scoreboard
        let newScoreboard = new.scoreboard
        let padel = scoreboard.padel
        let newPadel = newScoreboard.padel
        let generic = scoreboard.generic
        let newGeneric = newScoreboard.generic
        let golf = scoreboard.golf
        let newGolf = newScoreboard.golf
        let modular = scoreboard.modular
        let newModular = newScoreboard.modular
        if scoreboard.sport != newScoreboard.sport {
            scoreboard.sport = newScoreboard.sport
            scoreboard.sportChanged()
        }
        scoreboard.textColor = newScoreboard.textColor
        scoreboard.primaryBackgroundColor = newScoreboard.primaryBackgroundColor
        scoreboard.secondaryBackgroundColor = newScoreboard.secondaryBackgroundColor
        scoreboard.loadColors()
        padel.type = newPadel.type
        padel.homePlayer1 = newPadel.homePlayer1
        padel.homePlayer2 = newPadel.homePlayer2
        padel.awayPlayer1 = newPadel.awayPlayer1
        padel.awayPlayer2 = newPadel.awayPlayer2
        generic.home = newGeneric.home
        generic.away = newGeneric.away
        generic.title = newGeneric.title
        applyScoreboardClockUpdate(generic.clock, newGeneric.clock)
        golf.title = newGolf.title
        if golf.numberOfHoles != newGolf.numberOfHoles {
            golf.numberOfHoles = newGolf.numberOfHoles
            golf.numberOfHolesChanged()
        }
        golf.setPars(newGolf.pars)
        golf.players = newGolf.players.map { player in
            if let oldPlayer = golf.players.first(where: { $0.id == player.id }) {
                oldPlayer.name = player.name
                return oldPlayer
            }
            let newPlayer = SettingsWidgetGolfScoreboardPlayer(name: player.name)
            newPlayer.id = player.id
            return newPlayer
        }
        golf.showPars = newGolf.showPars
        applyScoreboardTeamUpdate(modular.home, newModular.home)
        applyScoreboardTeamUpdate(modular.away, newModular.away)
        applyScoreboardClockUpdate(modular.clock, newModular.clock)
        modular.layout = newModular.layout
        modular.width = newModular.width
        modular.rowHeight = newModular.rowHeight
        modular.isBold = newModular.isBold
        modular.showTitle = newModular.showTitle
        modular.showMoreStats = newModular.showMoreStats
        modular.showGlobalStatsBlock = newModular.showGlobalStatsBlock
        modular.showClock = newModular.showClock
        if !creating {
            scoreboardWidgetUpdated(widget: widget)
        }
    }

    private func updateAlertsWidget(_ widget: SettingsWidget, _ new: SettingsWidget, _ creating: Bool) {
        let alerts = widget.alerts
        let newAlerts = new.alerts
        let oldAlerts = remoteControlAllAlerts(alerts)
        for alert in remoteControlAllAlerts(newAlerts) {
            if let oldAlert = oldAlerts.first(where: { $0.id == alert.id }) {
                alert.videoName = oldAlert.videoName
            } else {
                alert.videoName = ""
                fixAlert(alert: alert)
            }
        }
        for command in newAlerts.chatBot.commands {
            command.name = command.name.lowercased().removeAllWhitespaces()
            command.imageType = alerts.chatBot.commands.first { $0.id == command.id }?.imageType ?? .file
        }
        newAlerts.twitch.cheers = alerts.twitch.cheers
        newAlerts.twitch.redemptions = alerts.twitch.redemptions
        newAlerts.quickButton = alerts.quickButton
        newAlerts.needsSubtitles = alerts.needsSubtitles
        newAlerts.ttsMonster = alerts.ttsMonster
        widget.alerts = newAlerts
        if !creating {
            fixAlertMedias()
        }
    }

    func remoteControlApplySceneUpdate(scene: SettingsScene, new: SettingsScene, creating: Bool) {
        scene.name = new.name
        applySceneEnabledUpdate(scene, new, creating)
        applySceneVideoSourceUpdate(scene, new, creating)
        applySceneQuickSwitchGroupUpdate(scene, new, creating)
        applySceneMicUpdate(scene, new, creating)
        applySceneBackgroundColorUpdate(scene, new, creating)
        applySceneWidgetsUpdate(scene, new)
    }

    private func applySceneEnabledUpdate(_ scene: SettingsScene, _ new: SettingsScene, _ creating: Bool) {
        var changes = ChangeTracker()
        if changes.apply(&scene.enabled, new.enabled), !creating {
            sceneEnabledChanged(scene: scene)
        }
    }

    private func applySceneVideoSourceUpdate(_ scene: SettingsScene, _ new: SettingsScene, _ creating: Bool) {
        let cameraChanged = cameraId(scene.videoSource) != cameraId(new.videoSource)
        let settingsCameraId = new.videoSource.toCameraId()
        if cameraChanged {
            scene.updateCameraId(settingsCameraId: settingsCameraId)
        }
        var changes = ChangeTracker()
        changes.apply(&scene.mirror, new.mirror)
        changes.apply(&scene.overrideVideoStabilizationMode, new.overrideVideoStabilizationMode)
        changes.apply(&scene.videoStabilizationMode, new.videoStabilizationMode)
        changes.apply(&scene.fillFrame, new.fillFrame)
        let settingsChanged = changes.changed
        let rotationChanged = changes.apply(&scene.videoSourceRotation, new.videoSourceRotation)
        guard !creating else {
            return
        }
        if cameraChanged {
            sceneSetCamera(scene: scene, settingsCameraId: settingsCameraId)
        } else if settingsChanged {
            sceneVideoSourceSettingsChanged()
        } else if rotationChanged {
            sceneVideoSourceRotationChanged()
        }
    }

    private func applySceneQuickSwitchGroupUpdate(_ scene: SettingsScene,
                                                  _ new: SettingsScene,
                                                  _ creating: Bool)
    {
        var changes = ChangeTracker()
        if changes.apply(&scene.quickSwitchGroup, new.quickSwitchGroup), !creating {
            sceneQuickSwitchGroupChanged(scene: scene)
        }
    }

    private func applySceneMicUpdate(_ scene: SettingsScene, _ new: SettingsScene, _ creating: Bool) {
        var changes = ChangeTracker()
        let overrideMicChanged = changes.apply(&scene.overrideMic, new.overrideMic)
        let micIdChanged = changes.apply(&scene.micId, new.micId)
        guard !creating else {
            return
        }
        if overrideMicChanged {
            switchMicIfNeededAfterSceneSwitch()
        } else if micIdChanged {
            sceneMicChanged(scene: scene)
        }
    }

    private func applySceneBackgroundColorUpdate(_ scene: SettingsScene,
                                                 _ new: SettingsScene,
                                                 _ creating: Bool)
    {
        var changes = ChangeTracker()
        if changes.apply(&scene.backgroundColor, new.backgroundColor) {
            scene.backgroundColorColor = scene.backgroundColor.color()
            if !creating {
                sceneBackgroundColorChanged()
            }
        }
    }

    private func applySceneWidgetsUpdate(_ scene: SettingsScene, _ new: SettingsScene) {
        let oldWidgetIds = scene.widgets.map(\.id)
        let newWidgetIds = new.widgets.map(\.id)
        let removedOrMoved = oldWidgetIds.contains { !newWidgetIds.contains($0) }
            || oldWidgetIds.filter(newWidgetIds.contains) != newWidgetIds.filter(oldWidgetIds.contains)
        let added = newWidgetIds.contains { !oldWidgetIds.contains($0) }
        let layoutsChanged = new.widgets.contains { sceneWidget in
            scene.widgets.first { $0.id == sceneWidget.id }.map { $0.layout != sceneWidget.layout } ?? false
        }
        let captureDeviceWidgetsChanged = captureDeviceWidgetIds(scene.widgets) !=
            captureDeviceWidgetIds(new.widgets)
        scene.widgets = remoteControlMergeSceneWidgets(scene.widgets, new.widgets)
        if removedOrMoved || added || layoutsChanged {
            sceneUpdated(attachCamera: getSelectedScene() === scene && captureDeviceWidgetsChanged)
        }
        if removedOrMoved {
            sceneSettingsPanelSceneId += 1
        }
    }

    private func captureDeviceWidgetIds(_ sceneWidgets: [SettingsSceneWidget]) -> Set<UUID> {
        Set(sceneWidgets
            .filter { sceneWidget in
                findWidget(id: sceneWidget.widgetId).map { isCaptureDeviceWidget(widget: $0) } ?? false
            }
            .map(\.widgetId))
    }

    private func cameraId(_ videoSource: SettingsVideoSource) -> CameraId {
        getCameraId(settingsCameraId: videoSource.toCameraId())
    }

    private func applyEffectsUpdate(
        widget: SettingsWidget,
        new: SettingsWidget,
        changes: inout ChangeTracker
    ) {
        var updatedEffects: [SettingsVideoEffect] = []
        let effects = new.effects.map { effect in
            guard let oldEffect = widget.effects.first(where: { $0.id == effect.id }) else {
                return effect
            }
            changes.apply(&oldEffect.enabled, effect.enabled)
            if applyEffectSettingsUpdate(oldEffect, effect) {
                updatedEffects.append(oldEffect)
            }
            return oldEffect
        }
        changes.applyItems(&widget.effects, effects)
        for effect in updatedEffects {
            updateWidgetVideoEffect(widget, effect)
        }
    }

    private func applyEffectSettingsUpdate(_ effect: SettingsVideoEffect,
                                           _ new: SettingsVideoEffect) -> Bool
    {
        var changes = ChangeTracker()
        switch effect.type {
        case .removeBackground:
            let removeBackground = effect.removeBackground
            if changes.apply(&removeBackground.from, new.removeBackground.from) {
                removeBackground.fromColor = removeBackground.from.color()
            }
            if changes.apply(&removeBackground.to, new.removeBackground.to) {
                removeBackground.toColor = removeBackground.to.color()
            }
        case .shape:
            let shape = effect.shape
            changes.apply(&shape.cornerRadius, new.shape.cornerRadius)
            changes.apply(&shape.borderWidth, new.shape.borderWidth)
            if changes.apply(&shape.borderColor, new.shape.borderColor) {
                shape.borderColorColor = shape.borderColor.color()
            }
            changes.apply(&shape.cropEnabled, new.shape.cropEnabled)
            changes.apply(&shape.cropX, new.shape.cropX)
            changes.apply(&shape.cropY, new.shape.cropY)
            changes.apply(&shape.cropWidth, new.shape.cropWidth)
            changes.apply(&shape.cropHeight, new.shape.cropHeight)
        case .dewarp360:
            let dewarp360 = effect.dewarp360
            changes.apply(&dewarp360.pan, new.dewarp360.pan)
            changes.apply(&dewarp360.tilt, new.dewarp360.tilt)
            if changes.apply(&dewarp360.inverseFieldOfView, new.dewarp360.inverseFieldOfView) {
                dewarp360.updateZoomFromInverseFieldOfView()
            }
        case .anamorphicLens:
            changes.apply(&effect.anamorphicLens.scale, new.anamorphicLens.scale)
        case .lut:
            changes.apply(&effect.lut.lut, new.lut.lut)
        case .opacity:
            changes.apply(&effect.opacity.opacity, new.opacity.opacity)
        case .mask:
            let mask = effect.mask
            changes.apply(&mask.points, new.mask.points)
            changes.apply(&mask.inverted, new.mask.inverted)
            changes.apply(&mask.tension, new.mask.tension)
            changes.apply(&mask.backgroundType, new.mask.backgroundType)
            if changes.apply(&mask.backgroundColor, new.mask.backgroundColor) {
                mask.backgroundColorColor = mask.backgroundColor.color()
            }
            if changes.apply(&mask.backgroundColor2, new.mask.backgroundColor2) {
                mask.backgroundColorColor2 = mask.backgroundColor2.color()
            }
        case .grayScale, .sepia, .whirlpool, .pinch:
            break
        }
        return changes.changed
    }

    private func updateWidgetVideoEffect(_ widget: SettingsWidget, _ effect: SettingsVideoEffect) {
        switch effect.type {
        case .removeBackground:
            removeBackgroundEffectSettingsChanged(widget: widget, effect: effect)
        case .shape:
            shapeEffectSettingsChanged(widget: widget, effect: effect)
        case .dewarp360:
            dewarp360EffectSettingsChanged(widget: widget, effect: effect)
        case .anamorphicLens:
            anamorphicLensEffectSettingsChanged(widget: widget, effect: effect)
        case .lut:
            lutEffectSettingsChanged(widget: widget, effect: effect)
        case .opacity:
            opacityEffectSettingsChanged(widget: widget, effect: effect)
        case .mask:
            maskEffectSettingsChanged(widget: widget, effect: effect)
        case .grayScale, .sepia, .whirlpool, .pinch:
            break
        }
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
}
