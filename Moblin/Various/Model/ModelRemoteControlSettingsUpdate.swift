import Foundation

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

struct RemoteControlWidgetUpdate {
    var reloadEffects = false
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
        guard new.type == widget.type,
              var update = applyWidgetTypeUpdate(widget: widget, new: new, creating: creating)
        else {
            return nil
        }
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
            resetSelectedScene(changeScene: false, attachCamera: update.attachCamera)
        } else if update.updateScene {
            sceneUpdated(attachCamera: update.attachCamera)
        }
        update.updateEffects()
    }

    private func applyWidgetTypeUpdate(widget: SettingsWidget,
                                       new: SettingsWidget,
                                       creating: Bool) -> RemoteControlWidgetUpdate?
    {
        switch widget.type {
        case .text:
            updateTextWidget(widget, new, creating: creating)
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
            updateSlideshowWidget(widget, new, creating: creating)
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
                                  _ new: SettingsWidget,
                                  creating: Bool) -> RemoteControlWidgetUpdate?
    {
        let text = widget.text
        let newText = new.text
        guard !creating || !newText.formatString.isEmpty,
              isValidChange(text.fontSize, newText.fontSize, { (10 ... 200).contains($0) }),
              isValidChange(text.width, newText.width, { $0 > 0 && $0 < 4000 }),
              isValidChange(text.cornerRadius, newText.cornerRadius, { $0 >= 0 && $0 < 1000 }),
              isValidChange(text.delay, newText.delay, { (0 ... 10).contains($0) }),
              zip(text.timers, newText.timers).allSatisfy({ timer, newTimer in
                  isValidChange(timer.delta, newTimer.delta) { [1, 2, 5, 15, 60].contains($0) }
              })
        else {
            return nil
        }
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
        for (timer, newTimer) in zip(text.timers, newText.timers) {
            timer.delta = newTimer.delta
        }
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
        }
    }

    private func updateBrowserWidget(_ widget: SettingsWidget,
                                     _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let browser = widget.browser
        let newBrowser = new.browser
        guard isValidEffectsUpdate(widget: widget, new: new),
              isValidChange(browser.url, newBrowser.url, { isValidHttpUrl(url: $0.trim()) == nil }),
              isValidChange(browser.width, newBrowser.width, { $0 > 0 && $0 < 4000 }),
              isValidChange(browser.height, newBrowser.height, { $0 > 0 && $0 < 4000 }),
              isValidChange(browser.baseFps, newBrowser.baseFps, { (1 ... 15).contains($0) })
        else {
            return nil
        }
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
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateCropWidget(_ widget: SettingsWidget,
                                  _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let crop = widget.crop
        let newCrop = new.crop
        guard isValidChange(crop.sourceWidgetId, newCrop.sourceWidgetId, { sourceWidgetId in
                  database.widgets.contains { $0.id == sourceWidgetId && $0.type == .browser }
              }),
              isValidChange(crop.x, newCrop.x, { $0 >= 0 }),
              isValidChange(crop.y, newCrop.y, { $0 >= 0 }),
              isValidChange(crop.width, newCrop.width, { $0 > 0 }),
              isValidChange(crop.height, newCrop.height, { $0 > 0 })
        else {
            return nil
        }
        var changes = ChangeTracker()
        changes.apply(&crop.sourceWidgetId, newCrop.sourceWidgetId)
        changes.apply(&crop.x, newCrop.x)
        changes.apply(&crop.y, newCrop.y)
        changes.apply(&crop.width, newCrop.width)
        changes.apply(&crop.height, newCrop.height)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateMapWidget(_ widget: SettingsWidget,
                                 _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let map = widget.map
        let newMap = new.map
        guard isValidEffectsUpdate(widget: widget, new: new),
              isValidChange(map.size, newMap.size, { (500 ... 10000).contains($0) }),
              isValidChange(map.delay, newMap.delay, { (0 ... 10).contains($0) })
        else {
            return nil
        }
        var changes = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&map.northUp, newMap.northUp)
        changes.apply(&map.size, newMap.size)
        changes.apply(&map.delay, newMap.delay)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateSceneWidget(_ widget: SettingsWidget,
                                   _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        guard isValidChange(widget.scene.sceneId, new.scene.sceneId, { sceneId in
            selectableScenes(widget: widget).contains { $0.id == sceneId }
        }) else {
            return nil
        }
        var changes = ChangeTracker()
        changes.apply(&widget.scene.sceneId, new.scene.sceneId)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed,
                                         attachCamera: isCaptureDeviceWidget(widget: widget))
    }

    private func updateQrCodeWidget(_ widget: SettingsWidget,
                                    _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        guard isValidEffectsUpdate(widget: widget, new: new) else {
            return nil
        }
        var changes = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        changes.apply(&widget.qrCode.message, new.qrCode.message)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateImageWidget(_ widget: SettingsWidget,
                                   _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        guard isValidEffectsUpdate(widget: widget, new: new) else {
            return nil
        }
        var changes = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &changes)
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateSnapshotWidget(_ widget: SettingsWidget,
                                      _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        guard isValidEffectsUpdate(widget: widget, new: new),
              isValidChange(widget.snapshot.showtime, new.snapshot.showtime, {
                  [3, 5, 10, 15, 30, 60, 120].contains($0)
              })
        else {
            return nil
        }
        var effects = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &effects)
        let showtimeChanged = widget.snapshot.showtime != new.snapshot.showtime
        widget.snapshot.showtime = new.snapshot.showtime
        return RemoteControlWidgetUpdate(reloadEffects: effects.changed) {
            if showtimeChanged {
                self.getSnapshotEffect(id: widget.id)?.setSettings(showtime: widget.snapshot.showtime)
            }
        }
    }

    private func updateChatWidget(_ widget: SettingsWidget,
                                  _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let chat = widget.chat
        let newChat = new.chat
        guard isValidChange(chat.fontSize, newChat.fontSize, { (10 ... 50).contains($0) }),
              isValidChange(chat.maximumNumberOfMessages, newChat.maximumNumberOfMessages, {
                  (1 ... 5).contains($0)
              }),
              isValidChange(chat.height, newChat.height, { (0.1 ... 1).contains($0) })
        else {
            return nil
        }
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
                                            _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let chatEmoteCombo = widget.chatEmoteCombo
        let newChatEmoteCombo = new.chatEmoteCombo
        guard isValidChange(chatEmoteCombo.minimumCombo, newChatEmoteCombo.minimumCombo, {
                  (2 ... 10).contains($0)
              }),
              isValidChange(
                  chatEmoteCombo.resetAfter,
                  newChatEmoteCombo.resetAfter,
                  { (3 ... 10).contains($0) }
              )
        else {
            return nil
        }
        chatEmoteCombo.minimumCombo = newChatEmoteCombo.minimumCombo
        chatEmoteCombo.resetAfter = newChatEmoteCombo.resetAfter
        return RemoteControlWidgetUpdate {
            self.getChatEmoteComboEffect(id: widget.id)?.setSettings(settings: chatEmoteCombo)
        }
    }

    private func updateSlideshowWidget(_ widget: SettingsWidget,
                                       _ new: SettingsWidget,
                                       creating: Bool) -> RemoteControlWidgetUpdate?
    {
        let slideshow = widget.slideshow
        let isValidSlide = { (slide: SettingsWidgetSlideshowSlide) in
            let oldSlide = slideshow.slides.first { $0.id == slide.id } ?? SettingsWidgetSlideshowSlide()
            return isValidChange(oldSlide.widgetId, slide.widgetId) { widgetId in
                guard let widgetId else {
                    return true
                }
                return self.database.widgets
                    .contains { $0.id == widgetId && [.text, .image].contains($0.type) }
            }
                && isValidChange(oldSlide.time, slide.time) {
                    [5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 300].contains($0)
                }
        }
        guard !creating || !new.slideshow.slides.isEmpty, new.slideshow.slides.allSatisfy(isValidSlide) else {
            return nil
        }
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
        return RemoteControlWidgetUpdate(reloadEffects: changes.changed)
    }

    private func updateWheelOfLuckWidget(_ widget: SettingsWidget,
                                         _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let wheelOfLuck = widget.wheelOfLuck
        let newWheelOfLuck = new.wheelOfLuck
        guard !newWheelOfLuck.options.isEmpty,
              newWheelOfLuck.options.allSatisfy({ option in
                  let oldOption = wheelOfLuck.options.first { $0.id == option.id }
                      ?? SettingsWidgetWheelOfLuckOption()
                  return isValidChange(oldOption.weight, option.weight) {
                      wheelOfLuckOptionWeights.contains($0)
                  }
                      && isValidChange(oldOption.function, option.function) {
                          ![
                              .zoomIn,
                              .zoomOut,
                              .gimbalUp,
                              .gimbalDown,
                              .gimbalLeft,
                              .gimbalRight,
                              .gimbalPreset,
                          ]
                          .contains($0)
                      }
              })
        else {
            return nil
        }
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
                                       _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
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
                                         _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let videoSource = widget.videoSource
        let newVideoSource = new.videoSource
        guard isValidEffectsUpdate(widget: widget, new: new),
              isValidCameraChange(videoSource.videoSource, newVideoSource.videoSource),
              isValidChange(
                  videoSource.rotation,
                  newVideoSource.rotation,
                  { videoSourceRotations.contains($0) }
              ),
              isValidChange(
                  videoSource.trackFaceZoom,
                  newVideoSource.trackFaceZoom,
                  { (0 ... 1).contains($0) }
              )
        else {
            return nil
        }
        var effects = ChangeTracker()
        applyEffectsUpdate(widget: widget, new: new, changes: &effects)
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
                                         attachCamera: cameraChanged || isCaptureDeviceWidget(widget: widget))
        {
            if settingsChanged {
                self.getVideoSourceEffect(id: widget.id)?
                    .setSettings(settings: videoSource.toEffectSettings())
                self.updateCameraPreviewWidgets()
            }
        }
    }

    private func updateVTuberWidget(_ widget: SettingsWidget,
                                    _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let vTuber = widget.vTuber
        let newVTuber = new.vTuber
        guard isValidCameraChange(vTuber.videoSource, newVTuber.videoSource),
              isValidChange(vTuber.cameraPositionY, newVTuber.cameraPositionY, { (1 ... 2).contains($0) }),
              isValidChange(
                  vTuber.cameraFieldOfView,
                  newVTuber.cameraFieldOfView,
                  { (10 ... 30).contains($0) }
              ),
              isValidChange(vTuber.armsAngle, newVTuber.armsAngle, { (20 ... 90).contains($0) }),
              isValidSensitivityUpdate(vTuber.sensitivity, newVTuber.sensitivity)
        else {
            return nil
        }
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
                                      _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let pngTuber = widget.pngTuber
        let newPngTuber = new.pngTuber
        guard isValidCameraChange(pngTuber.videoSource, newPngTuber.videoSource),
              isValidSensitivityUpdate(pngTuber.sensitivity, newPngTuber.sensitivity)
        else {
            return nil
        }
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
                                           _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let pomodoroTimer = widget.pomodoroTimer
        let newPomodoroTimer = new.pomodoroTimer
        guard isValidChange(pomodoroTimer.focusDuration, newPomodoroTimer.focusDuration, {
                  [1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120].contains($0)
              }),
              isValidChange(pomodoroTimer.breakDuration, newPomodoroTimer.breakDuration, {
                  [1, 2, 3, 5, 7, 10, 15, 20, 25, 30].contains($0)
              }),
              isValidChange(pomodoroTimer.width, newPomodoroTimer.width, { (1 ... 5).contains($0) }),
              isValidChange(pomodoroTimer.focusToBreakSoundId, newPomodoroTimer.focusToBreakSoundId, {
                  isValidAlertSoundId($0)
              }),
              isValidChange(pomodoroTimer.breakToFocusSoundId, newPomodoroTimer.breakToFocusSoundId, {
                  isValidAlertSoundId($0)
              })
        else {
            return nil
        }
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
                                        _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let scoreboard = widget.scoreboard
        let newScoreboard = new.scoreboard
        let isValidPlayerId = { (playerId: UUID) in
            self.database.scoreboardPlayers.contains { $0.id == playerId }
        }
        let padel = scoreboard.padel
        let newPadel = newScoreboard.padel
        let generic = scoreboard.generic
        let newGeneric = newScoreboard.generic
        let golf = scoreboard.golf
        let newGolf = newScoreboard.golf
        let modular = scoreboard.modular
        let newModular = newScoreboard.modular
        guard isValidChange(padel.homePlayer1, newPadel.homePlayer1, isValidPlayerId),
              isValidChange(padel.homePlayer2, newPadel.homePlayer2, isValidPlayerId),
              isValidChange(padel.awayPlayer1, newPadel.awayPlayer1, isValidPlayerId),
              isValidChange(padel.awayPlayer2, newPadel.awayPlayer2, isValidPlayerId),
              isValidChange(generic.clock.maximum, newGeneric.clock.maximum, { (1 ... 180).contains($0) }),
              isValidChange(golf.numberOfHoles, newGolf.numberOfHoles, { [9, 18].contains($0) }),
              isValidChange(golf.pars, newGolf.pars, { $0.allSatisfy { (1 ... 9).contains($0) } }),
              isValidChange(golf.players.count, newGolf.players.count, { $0 <= 4 }),
              isValidChange(modular.clock.maximum, newModular.clock.maximum, { (1 ... 180).contains($0) }),
              isValidChange(modular.width, newModular.width, { (100 ... 1000).contains($0) }),
              isValidChange(modular.rowHeight, newModular.rowHeight, { (10 ... 150).contains($0) })
        else {
            return nil
        }
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
                                    _ new: SettingsWidget) -> RemoteControlWidgetUpdate?
    {
        let alerts = widget.alerts
        let newAlerts = new.alerts
        let oldAlerts = allAlerts(alerts)
        guard allAlerts(newAlerts).allSatisfy({ alert in
                  guard let oldAlert = oldAlerts.first(where: { $0.id == alert.id }) else {
                      return isValidAlertUpdate(SettingsWidgetAlertsAlert(), alert, checkMedia: false)
                  }
                  return isValidAlertUpdate(oldAlert, alert, checkMedia: true)
              }),
              isValidChange(alerts.aiEnabled, newAlerts.aiEnabled, { !$0 || newAlerts.ai.isConfigured() }),
              isValidChange(alerts.ai.baseUrl, newAlerts.ai.baseUrl, { isValidHttpUrl(url: $0) == nil })
        else {
            return nil
        }
        for alert in allAlerts(newAlerts) {
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

    func remoteControlApplySceneUpdate(scene: SettingsScene, new: SettingsScene) -> Bool {
        let selected = getSelectedScene() === scene
        let overrideMicChanged = scene.overrideMic != new.overrideMic
        let quickSwitchGroupChanged = scene.quickSwitchGroup != new.quickSwitchGroup
        let attachCamera = cameraId(scene.videoSource) != cameraId(new.videoSource)
            || scene.mirror != new.mirror
            || scene.overrideVideoStabilizationMode != new.overrideVideoStabilizationMode
            || scene.videoStabilizationMode != new.videoStabilizationMode
            || scene.fillFrame != new.fillFrame
            || captureDeviceWidgetIds(scene.widgets) != captureDeviceWidgetIds(new.widgets)
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
        return attachCamera
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

    private func isValidCameraChange(_ old: SettingsVideoSource, _ new: SettingsVideoSource) -> Bool {
        isValidChange(cameraId(old), cameraId(new)) { cameraId in
            videoSources.all().contains { $0.id == cameraId }
        }
    }

    private func isValidEffectsUpdate(widget: SettingsWidget, new: SettingsWidget) -> Bool {
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

    private func applyEffectsUpdate(
        widget: SettingsWidget,
        new: SettingsWidget,
        changes: inout ChangeTracker
    ) {
        let effects = new.effects.map { effect in
            guard let oldEffect = widget.effects.first(where: { $0.id == effect.id }) else {
                return effect
            }
            applyEffectUpdate(oldEffect, effect, &changes)
            return oldEffect
        }
        changes.applyItems(&widget.effects, effects)
    }

    private func applyEffectUpdate(_ effect: SettingsVideoEffect,
                                   _ new: SettingsVideoEffect,
                                   _ changes: inout ChangeTracker)
    {
        changes.apply(&effect.enabled, new.enabled)
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
            changes.apply(&dewarp360.zoom, new.dewarp360.zoom)
            changes.apply(&dewarp360.inverseFieldOfView, new.dewarp360.inverseFieldOfView)
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

    private func isValidSensitivityUpdate(_ old: SettingsSensitivity, _ new: SettingsSensitivity) -> Bool {
        isValidChange(old.mouth, new.mouth) { (0.05 ... 3).contains($0) }
            && isValidChange(old.eyes, new.eyes) { (0.05 ... 5).contains($0) }
    }

    private func isValidAlertSoundId(_ soundId: UUID?) -> Bool {
        soundId.map { soundId in getAllAlertSounds().contains { $0.id == soundId } } ?? true
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
}
