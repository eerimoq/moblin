import Foundation

struct RemoteControlWidgetUpdate {
    var reloadEffects = false
    var reloadEffectsAttachCamera = true
    var updateScene = false
    var attachCamera = false
    var updateEffects: () -> Void = {}
}

private struct ChangeTracker {
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
        guard remoteControlApplyWidgetUpdate(widget: newWidget, new: widget, creating: true) != nil else {
            return nil
        }
        return newWidget
    }

    func remoteControlApplyWidgetUpdate(widget: SettingsWidget,
                                        new: SettingsWidget,
                                        creating: Bool) -> RemoteControlWidgetUpdate?
    {
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
            return nil
        }
        var update = applyWidgetTypeUpdate(widget: widget, new: new)
        widget.name = new.name
        if widget.enabled != new.enabled {
            widget.enabled = new.enabled
            update.updateScene = true
            update.attachCamera = update.attachCamera || isCaptureDeviceWidget(widget: widget)
        }
        return update
    }

    func remoteControlWidgetUpdated(update: RemoteControlWidgetUpdate) {
        if update.reloadEffects {
            resetSelectedScene(changeScene: false,
                               attachCamera: update.reloadEffectsAttachCamera || update.attachCamera)
        } else if update.updateScene {
            sceneUpdated(attachCamera: update.attachCamera)
        }
        update.updateEffects()
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

    private func applyWidgetTypeUpdate(widget: SettingsWidget,
                                       new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        switch widget.type {
        case .text:
            updateTextWidget(widget, new)
        case .browser:
            updateBrowserWidget(widget, new)
        case .crop:
            updateCropWidget(widget, new)
        case .map:
            updateMapWidget(widget, new)
        case .scene:
            updateSceneWidget(widget, new)
        case .qrCode:
            updateQrCodeWidget(widget, new)
        case .image:
            updateImageWidget(widget, new)
        case .snapshot:
            updateSnapshotWidget(widget, new)
        case .chat:
            updateChatWidget(widget, new)
        case .chatEmoteCombo:
            updateChatEmoteComboWidget(widget, new)
        case .slideshow:
            updateSlideshowWidget(widget, new)
        case .wheelOfLuck:
            updateWheelOfLuckWidget(widget, new)
        case .bingoCard:
            updateBingoCardWidget(widget, new)
        case .videoSource:
            updateVideoSourceWidget(widget, new)
        case .vTuber:
            updateVTuberWidget(widget, new)
        case .pngTuber:
            updatePngTuberWidget(widget, new)
        case .pomodoroTimer:
            updatePomodoroTimerWidget(widget, new)
        case .scoreboard:
            updateScoreboardWidget(widget, new)
        case .alerts:
            updateAlertsWidget(widget, new)
        }
    }

    private func updateTextWidget(_ widget: SettingsWidget,
                                  _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let text = widget.text
        let newText = new.text
        let formatChanged = text.formatString != newText.formatString
        text.formatString = newText.formatString
        var style = ChangeTracker()
        if style.apply(&text.backgroundColor, newText.backgroundColor) {
            text.backgroundColorColor = text.backgroundColor.color()
        }
        if style.apply(&text.foregroundColor, newText.foregroundColor) {
            text.foregroundColorColor = text.foregroundColor.color()
        }
        if style.apply(&text.fontSize, newText.fontSize) {
            text.fontSizeFloat = Float(text.fontSize)
        }
        style.apply(&text.font, newText.font)
        style.apply(&text.fontDesign, newText.fontDesign)
        style.apply(&text.fontWeight, newText.fontWeight)
        style.apply(&text.fontMonospacedDigits, newText.fontMonospacedDigits)
        style.apply(&text.horizontalAlignment, newText.horizontalAlignment)
        style.apply(&text.widthEnabled, newText.widthEnabled)
        style.apply(&text.width, newText.width)
        style.apply(&text.cornerRadius, newText.cornerRadius)
        let styleChanged = style.changed
        let delayChanged = text.delay != newText.delay
        text.delay = newText.delay
        return RemoteControlWidgetUpdate(reloadEffects: delayChanged) {
            if styleChanged {
                for effect in self.getTextEffects(id: widget.id) {
                    effect.setBackgroundColor(color: text.backgroundColor)
                    effect.setForegroundColor(color: text.foregroundColor)
                    effect.setFontSize(size: CGFloat(text.fontSize))
                    effect.setFont(font: text.font)
                    effect.setFontDesign(design: text.fontDesign.toSystem())
                    effect.setFontWeight(weight: text.fontWeight.toSystem())
                    effect.setFontMonospacedDigits(enabled: text.fontMonospacedDigits)
                    effect.setLayout(alignment: text.horizontalAlignment.toSystem(),
                                     width: text.widthEnabled ? text.width : nil,
                                     cornerRadius: Double(text.cornerRadius))
                }
                self.remoteSceneSettingsUpdated()
            }
            if formatChanged {
                self.textWidgetTextChanged(widget: widget)
            }
            for (timer, newTimer) in zip(text.timers, newText.timers) {
                timer.delta = newTimer.delta
            }
        }
    }

    private func updateBrowserWidget(_ widget: SettingsWidget,
                                     _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let browser = widget.browser
        let newBrowser = new.browser
        var changes = ChangeTracker()
        let updateVideoEffects = applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&browser.url, newBrowser.url.trim())
        changes.apply(&browser.styleSheet, newBrowser.styleSheet.trim())
        changes.apply(&browser.width, newBrowser.width)
        changes.apply(&browser.height, newBrowser.height)
        changes.apply(&browser.localOnly, newBrowser.localOnly)
        changes.apply(&browser.mode, newBrowser.mode)
        changes.apply(&browser.baseFps, newBrowser.baseFps)
        changes.apply(&browser.moblinAccess, newBrowser.moblinAccess)
        changes.apply(&browser.speechToText, newBrowser.speechToText)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed, updateEffects: updateVideoEffects)
    }

    private func updateCropWidget(_ widget: SettingsWidget,
                                  _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let crop = widget.crop
        let newCrop = new.crop
        var changes = ChangeTracker()
        changes.apply(&crop.sourceWidgetId, newCrop.sourceWidgetId)
        changes.apply(&crop.x, newCrop.x)
        changes.apply(&crop.y, newCrop.y)
        changes.apply(&crop.width, newCrop.width)
        changes.apply(&crop.height, newCrop.height)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateMapWidget(_ widget: SettingsWidget,
                                 _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let map = widget.map
        let newMap = new.map
        var changes = ChangeTracker()
        let updateVideoEffects = applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&map.northUp, newMap.northUp)
        changes.apply(&map.size, newMap.size)
        changes.apply(&map.delay, newMap.delay)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed, updateEffects: updateVideoEffects)
    }

    private func updateSceneWidget(_ widget: SettingsWidget,
                                   _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        var changes = ChangeTracker()
        changes.apply(&widget.scene.sceneId, new.scene.sceneId)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateQrCodeWidget(_ widget: SettingsWidget,
                                    _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        var changes = ChangeTracker()
        let updateVideoEffects = applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&widget.qrCode.message, new.qrCode.message)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed, updateEffects: updateVideoEffects)
    }

    private func updateImageWidget(_ widget: SettingsWidget,
                                   _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        var changes = ChangeTracker()
        let updateVideoEffects = applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed, updateEffects: updateVideoEffects)
    }

    private func updateSnapshotWidget(_ widget: SettingsWidget,
                                      _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        var effects = ChangeTracker()
        let updateVideoEffects = applyEffectsUpdate(widget: widget, new: new, changes: &effects)
        let showtimeChanged = widget.snapshot.showtime != new.snapshot.showtime
        widget.snapshot.showtime = new.snapshot.showtime
        return RemoteControlWidgetUpdate(reloadEffects: effects.changed) {
            updateVideoEffects()
            if showtimeChanged {
                self.getSnapshotEffect(id: widget.id)?.setSettings(showtime: widget.snapshot.showtime)
            }
        }
    }

    private func updateChatWidget(_ widget: SettingsWidget,
                                  _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let chat = widget.chat
        let newChat = new.chat
        chat.fontSize = newChat.fontSize
        chat.font = newChat.font
        chat.usernameColor = newChat.usernameColor
        chat.usernameColorColor = newChat.usernameColor.color()
        chat.messageColor = newChat.messageColor
        chat.messageColorColor = newChat.messageColor.color()
        chat.backgroundColor = newChat.backgroundColor
        chat.backgroundColorColor = newChat.backgroundColor.color()
        chat.backgroundColorEnabled = newChat.backgroundColorEnabled
        chat.shadowColor = newChat.shadowColor
        chat.shadowColorColor = newChat.shadowColor.color()
        chat.shadowColorEnabled = newChat.shadowColorEnabled
        chat.boldUsername = newChat.boldUsername
        chat.boldMessage = newChat.boldMessage
        chat.badges = newChat.badges
        chat.displayStyle = newChat.displayStyle
        chat.sharedChatIcons = newChat.sharedChatIcons
        chat.height = newChat.height
        chat.maximumNumberOfMessages = newChat.maximumNumberOfMessages
        return RemoteControlWidgetUpdate {
            self.getChatEffect(id: widget.id)?.setSettings(settings: chat)
            self.updateWidgetOutlines()
        }
    }

    private func updateChatEmoteComboWidget(_ widget: SettingsWidget,
                                            _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let chatEmoteCombo = widget.chatEmoteCombo
        let newChatEmoteCombo = new.chatEmoteCombo
        chatEmoteCombo.minimumCombo = newChatEmoteCombo.minimumCombo
        chatEmoteCombo.resetAfter = newChatEmoteCombo.resetAfter
        return RemoteControlWidgetUpdate {
            self.getChatEmoteComboEffect(id: widget.id)?.setSettings(settings: chatEmoteCombo)
        }
    }

    private func updateSlideshowWidget(_ widget: SettingsWidget,
                                       _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
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
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed, reloadEffectsAttachCamera: false)
    }

    private func updateWheelOfLuckWidget(_ widget: SettingsWidget,
                                         _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let wheelOfLuck = widget.wheelOfLuck
        let newWheelOfLuck = new.wheelOfLuck
        wheelOfLuck.advanced = newWheelOfLuck.advanced
        wheelOfLuck.onlyShowWhenSpinning = newWheelOfLuck.onlyShowWhenSpinning
        wheelOfLuck.options = newWheelOfLuck.options.map { option in
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
        return RemoteControlWidgetUpdate {
            self.updateWheelOfLuckEffect(widget: widget)
        }
    }

    private func updateBingoCardWidget(_ widget: SettingsWidget,
                                       _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let bingoCard = widget.bingoCard
        let newBingoCard = new.bingoCard
        bingoCard.backgroundColor = newBingoCard.backgroundColor
        bingoCard.backgroundColorColor = newBingoCard.backgroundColor.color()
        bingoCard.foregroundColor = newBingoCard.foregroundColor
        bingoCard.foregroundColorColor = newBingoCard.foregroundColor.color()
        bingoCard.squares = newBingoCard.squares
        bingoCard.squaresText = newBingoCard.squaresText
        return RemoteControlWidgetUpdate {
            self.getBingoCardEffect(id: widget.id)?.setSettings(settings: bingoCard)
        }
    }

    private func updateVideoSourceWidget(_ widget: SettingsWidget,
                                         _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let videoSource = widget.videoSource
        let newVideoSource = new.videoSource
        var effects = ChangeTracker()
        let updateVideoEffects = applyEffectsUpdate(widget: widget, new: new, changes: &effects)
        let cameraChanged = cameraId(videoSource.videoSource) != cameraId(newVideoSource.videoSource)
        if cameraChanged {
            videoSource.updateCameraId(settingsCameraId: newVideoSource.videoSource.toCameraId())
        }
        var settings = ChangeTracker()
        settings.apply(&videoSource.rotation, newVideoSource.rotation)
        settings.apply(&videoSource.mirror, newVideoSource.mirror)
        settings.apply(&videoSource.trackFaceEnabled, newVideoSource.trackFaceEnabled)
        settings.apply(&videoSource.trackFaceZoom, newVideoSource.trackFaceZoom)
        let settingsChanged = settings.changed
        return RemoteControlWidgetUpdate(reloadEffects: effects.changed,
                                         updateScene: cameraChanged,
                                         attachCamera: cameraChanged)
        {
            updateVideoEffects()
            if settingsChanged {
                self.getVideoSourceEffect(id: widget.id)?
                    .setSettings(settings: videoSource.toEffectSettings())
                self.updateCameraPreviewWidgets()
            }
        }
    }

    private func updateVTuberWidget(_ widget: SettingsWidget,
                                    _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let vTuber = widget.vTuber
        let newVTuber = new.vTuber
        let cameraChanged = cameraId(vTuber.videoSource) != cameraId(newVTuber.videoSource)
        if cameraChanged {
            vTuber.updateCameraId(settingsCameraId: newVTuber.videoSource.toCameraId())
        }
        var settings = ChangeTracker()
        settings.apply(&vTuber.cameraPositionY, newVTuber.cameraPositionY)
        settings.apply(&vTuber.cameraFieldOfView, newVTuber.cameraFieldOfView)
        settings.apply(&vTuber.mirror, newVTuber.mirror)
        settings.apply(&vTuber.sensitivity, newVTuber.sensitivity)
        settings.apply(&vTuber.armsAngle, newVTuber.armsAngle)
        let settingsChanged = settings.changed
        return RemoteControlWidgetUpdate(updateScene: cameraChanged, attachCamera: cameraChanged) {
            if settingsChanged {
                self.getVTuberEffect(id: widget.id)?.setSettings(
                    cameraFieldOfView: vTuber.cameraFieldOfView,
                    cameraPositionY: vTuber.cameraPositionY,
                    mirror: vTuber.mirror,
                    sensitivity: vTuber.sensitivity,
                    armsAngle: vTuber.armsAngle
                )
            }
        }
    }

    private func updatePngTuberWidget(_ widget: SettingsWidget,
                                      _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let pngTuber = widget.pngTuber
        let newPngTuber = new.pngTuber
        let cameraChanged = cameraId(pngTuber.videoSource) != cameraId(newPngTuber.videoSource)
        if cameraChanged {
            pngTuber.updateCameraId(settingsCameraId: newPngTuber.videoSource.toCameraId())
        }
        var settings = ChangeTracker()
        settings.apply(&pngTuber.mirror, newPngTuber.mirror)
        settings.apply(&pngTuber.sensitivity, newPngTuber.sensitivity)
        let settingsChanged = settings.changed
        return RemoteControlWidgetUpdate(updateScene: cameraChanged, attachCamera: cameraChanged) {
            if settingsChanged {
                self.getPngTuberEffect(id: widget.id)?.setSettings(mirror: pngTuber.mirror,
                                                                   sensitivity: pngTuber.sensitivity)
            }
        }
    }

    private func updatePomodoroTimerWidget(_ widget: SettingsWidget,
                                           _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
        let pomodoroTimer = widget.pomodoroTimer
        let newPomodoroTimer = new.pomodoroTimer
        if pomodoroTimer.focusDuration != newPomodoroTimer.focusDuration {
            pomodoroTimer.focusDuration = newPomodoroTimer.focusDuration
            if pomodoroTimer.phase == .focus, !pomodoroTimer.isRunning {
                pomodoroTimer.secondsRemaining = pomodoroTimer.focusDuration * 60
            }
        }
        if pomodoroTimer.breakDuration != newPomodoroTimer.breakDuration {
            pomodoroTimer.breakDuration = newPomodoroTimer.breakDuration
            if pomodoroTimer.phase == .shortBreak, !pomodoroTimer.isRunning {
                pomodoroTimer.secondsRemaining = pomodoroTimer.breakDuration * 60
            }
        }
        pomodoroTimer.width = newPomodoroTimer.width
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
        return RemoteControlWidgetUpdate {
            self.updateWidgetOutlines()
        }
    }

    private func updateScoreboardWidget(_ widget: SettingsWidget,
                                        _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
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
            modular.config = nil
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
            golf.currentHole = 0
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
        return RemoteControlWidgetUpdate {
            self.remoteControlScoreboardWidgetUpdated(widget: widget)
        }
    }

    private func updateAlertsWidget(_ widget: SettingsWidget,
                                    _ new: SettingsWidget) -> RemoteControlWidgetUpdate
    {
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
        return RemoteControlWidgetUpdate {
            self.fixAlertMedias()
        }
    }

    func remoteControlApplySceneUpdate(scene: SettingsScene, new: SettingsScene, creating: Bool) {
        let enabledChanged = scene.enabled != new.enabled
        let cameraChanged = cameraId(scene.videoSource) != cameraId(new.videoSource)
        let attachCameraChanged = !creating && cameraChanged
            || scene.mirror != new.mirror
            || scene.overrideVideoStabilizationMode != new.overrideVideoStabilizationMode
            || scene.videoStabilizationMode != new.videoStabilizationMode
            || scene.fillFrame != new.fillFrame
        let rotationChanged = scene.videoSourceRotation != new.videoSourceRotation
        let quickSwitchGroupChanged = scene.quickSwitchGroup != new.quickSwitchGroup
        let overrideMicChanged = scene.overrideMic != new.overrideMic
        let micIdChanged = scene.micId != new.micId
        let backgroundColorChanged = scene.backgroundColor != new.backgroundColor
        let oldWidgetIds = scene.widgets.map(\.id)
        let newWidgetIds = new.widgets.map(\.id)
        let widgetsRemovedOrMoved = oldWidgetIds.contains { !newWidgetIds.contains($0) }
            || oldWidgetIds.filter(newWidgetIds.contains) != newWidgetIds.filter(oldWidgetIds.contains)
        let widgetsAdded = newWidgetIds.contains { !oldWidgetIds.contains($0) }
        let layoutsChanged = new.widgets.contains { sceneWidget in
            scene.widgets.first { $0.id == sceneWidget.id }.map { $0.layout != sceneWidget.layout } ?? false
        }
        let captureDeviceWidgetsChanged = captureDeviceWidgetIds(scene.widgets) !=
            captureDeviceWidgetIds(new.widgets)
        scene.name = new.name
        scene.enabled = new.enabled
        if cameraChanged {
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
        scene.widgets = remoteControlMergeSceneWidgets(scene.widgets, new.widgets)
        let selected = getSelectedScene() === scene
        let widgetsChanged = widgetsRemovedOrMoved || widgetsAdded || layoutsChanged
        if enabledChanged, selected {
            resetSelectedScene()
        } else if quickSwitchGroupChanged, selected {
            resetSelectedScene(changeScene: false, attachCamera: true)
        } else if attachCameraChanged || rotationChanged || widgetsChanged {
            sceneUpdated(attachCamera: attachCameraChanged || selected && captureDeviceWidgetsChanged,
                         updateRemoteScene: widgetsChanged)
        }
        if enabledChanged, !selected {
            sceneSelector.sceneIndex += 0
        }
        if overrideMicChanged || micIdChanged && selected {
            switchMicIfNeededAfterSceneSwitch()
        }
        if backgroundColorChanged {
            sceneSelector.objectWillChange.send()
        }
        if widgetsRemovedOrMoved {
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

    private func applyEffectsUpdate(
        widget: SettingsWidget,
        new: SettingsWidget,
        changes: inout ChangeTracker
    ) -> () -> Void {
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
        return {
            for effect in updatedEffects {
                self.updateWidgetVideoEffect(widget, effect)
            }
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
            getWidgetRemoveBackgroundEffect(widget, effect)?.setColorRange(
                from: effect.removeBackground.from,
                to: effect.removeBackground.to
            )
        case .shape:
            getWidgetShapeEffect(widget, effect)?.setSettings(settings: effect.shape.toSettings())
            updateCameraPreviewWidgets()
        case .dewarp360:
            getWidgetDewarp360Effect(widget, effect)?.setSettings(settings: effect.dewarp360.toSettings())
        case .anamorphicLens:
            getWidgetAnamorphicLensEffect(widget, effect)?
                .setSettings(settings: effect.anamorphicLens.clone())
        case .lut:
            getWidgetLutEffect(widget, effect)?.setLut(lut: getLogLutById(id: effect.lut.lut),
                                                       imageStorage: imageStorage)
            {
                self.makeErrorToast(title: $0, subTitle: $1)
            }
        case .opacity:
            getWidgetOpacityEffect(widget, effect)?.setOpacity(opacity: effect.opacity.opacity)
        case .mask:
            getWidgetMaskEffect(widget, effect)?.setSettings(settings: effect.mask.toEffectSettings())
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
