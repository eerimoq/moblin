import AVFoundation
import Foundation

extension Model {
    func startMacro(macro: SettingsMacrosMacro) {
        guard !macro.running else {
            return
        }
        macro.running = true
        macro.nextActionIndex = 0
        macro.stack = [macro]
        executeNextAction(macro: macro)
    }

    func stopMacro(macro: SettingsMacrosMacro) {
        guard macro.running else {
            return
        }
        macro.running = false
        macro.finished = false
        for macro in macro.stack {
            macro.delayTimer.stop()
            macro.finishedTimer.stop()
        }
        macro.stack.removeAll()
    }

    func toggleMacroStartStop(id: UUID) {
        guard let macro = database.macros.macros.first(where: { $0.id == id }) else {
            return
        }
        if macro.running {
            stopMacro(macro: macro)
        } else if !macro.finished {
            startMacro(macro: macro)
        }
    }

    func removeDeadMacrosSettings() {
        for macro in database.macros.macros {
            for action in macro.actions {
                action.sceneIds = action.sceneIds.filter { id in
                    database.scenes.map(\.id).contains(id)
                }
                action.djiDevices = action.djiDevices.filter { id in
                    database.djiDevices.devices.map(\.id).contains(id)
                }
            }
        }
    }

    private func executeNextAction(macro: SettingsMacrosMacro) {
        guard let currentMacro = macro.stack.last else {
            return
        }
        guard currentMacro.nextActionIndex < currentMacro.actions.count else {
            currentMacro.running = false
            currentMacro.finished = true
            currentMacro.finishedTimer.startSingleShot(timeout: 2.0) {
                currentMacro.finished = false
            }
            macro.stack.removeLast()
            executeNextAction(macro: macro)
            return
        }
        let action = currentMacro.actions[currentMacro.nextActionIndex]
        currentMacro.nextActionIndex += 1
        let executeNext: Bool = switch action.function {
        case .scene:
            executeScene(action: action)
        case .enableDisableScenes:
            executeEnableDisableScenes(action: action)
        case .autoSceneSwitcher:
            executeAutoSceneSwitcher(action: action)
        case .zoom:
            executeZoom(action: action)
        case .gimbalPreset:
            executeGimbalPreset(action: action)
        case .delay:
            executeDelay(currentMacro: currentMacro,
                         action: action,
                         macro: macro)
        case .macro:
            executeMacro(action: action, macro: macro)
        case .djiDevices:
            executeDjiDevices(action: action)
        case .record:
            executeRecord(action: action)
        case .mute:
            executeMute(action: action)
        case .torch:
            executeTorch(action: action)
        case .snapshot:
            executeSnapshot()
        case .filters:
            executeFilters(action: action)
        case .reaction:
            executeReaction(action: action)
        case nil:
            true
        }
        if executeNext {
            executeNextAction(macro: macro)
        }
    }

    private func executeScene(action: SettingsMacrosAction) -> Bool {
        if let sceneId = action.sceneId {
            selectScene(id: sceneId)
        }
        return true
    }

    private func executeEnableDisableScenes(action: SettingsMacrosAction) -> Bool {
        for scene in database.scenes {
            scene.enabled = action.sceneIds.contains(scene.id)
        }
        sceneSelector.trigger += 1
        return true
    }

    private func executeAutoSceneSwitcher(action: SettingsMacrosAction) -> Bool {
        setAutoSceneSwitcher(id: action.autoSceneSwitcherId)
        return true
    }

    private func executeZoom(action: SettingsMacrosAction) -> Bool {
        setZoomX(x: action.zoomX, rate: database.zoom.speed)
        return true
    }

    private func executeGimbalPreset(action: SettingsMacrosAction) -> Bool {
        if let gimbalPresetId = action.gimbalPresetId {
            moveToGimbalPreset(id: gimbalPresetId)
        }
        return true
    }

    private func executeDelay(currentMacro: SettingsMacrosMacro,
                              action: SettingsMacrosAction,
                              macro: SettingsMacrosMacro) -> Bool
    {
        currentMacro.delayTimer.startSingleShot(timeout: action.delay) {
            self.executeNextAction(macro: macro)
        }
        return false
    }

    private func executeMacro(action: SettingsMacrosAction, macro: SettingsMacrosMacro) -> Bool {
        guard let subMacro = database.macros.macros.first(where: { $0.id == action.macroId }),
              !macro.stack.contains(where: { $0.id == subMacro.id })
        else {
            return true
        }
        macro.stack.append(subMacro.copy())
        return true
    }

    private func executeFilters(action: SettingsMacrosAction) -> Bool {
        for filter in SettingsQuickButtonType.filters() {
            let on = action.filters.contains(filter)
            switch filter {
            case .pixellate:
                setPixellateQuickButton(on: on)
            case .movie:
                setFilterQuickButton(type: .movie, on: on)
            case .grayScale:
                setFilterQuickButton(type: .grayScale, on: on)
            case .sepia:
                setFilterQuickButton(type: .sepia, on: on)
            case .triple:
                setFilterQuickButton(type: .triple, on: on)
            case .twin:
                setFilterQuickButton(type: .twin, on: on)
            case .fourThree:
                setFilterQuickButton(type: .fourThree, on: on)
            case .crt:
                setFilterQuickButton(type: .crt, on: on)
            case .pinch:
                setPinchQuickButton(on: on)
            case .whirlpool:
                setWhirlpoolQuickButton(on: on)
            case .poll:
                setPollQuickButton(on: on)
            case .blurFaces:
                setBlurFaces(on: on)
            case .privacy:
                setPrivacy(on: on)
            case .beauty:
                setBeautyQuickButton(on: on)
            case .moblinInMouth:
                setMoblinInMouth(on: on)
            case .cameraMan:
                setCameraManQuickButton(on: on)
            default:
                logger.info("macro: Filter button \(filter) not supported")
            }
        }
        return true
    }

    private func executeDjiDevices(action: SettingsMacrosAction) -> Bool {
        reloadDjiDevices(enabledDeviceIds: action.djiDevices)
        return true
    }

    private func executeRecord(action: SettingsMacrosAction) -> Bool {
        if action.record {
            startRecording()
        } else {
            stopRecording()
        }
        return true
    }

    private func executeMute(action: SettingsMacrosAction) -> Bool {
        setMuted(value: action.mute)
        setQuickButton(type: .mute, isOn: action.mute)
        updateQuickButtonStates()
        return true
    }

    private func executeTorch(action: SettingsMacrosAction) -> Bool {
        setTorch(on: action.torch)
        setQuickButton(type: .torch, isOn: action.torch)
        updateQuickButtonStates()
        return true
    }

    private func executeSnapshot() -> Bool {
        takeSnapshot()
        return true
    }

    private func executeReaction(action: SettingsMacrosAction) -> Bool {
        guard #available(iOS 17, *) else {
            return true
        }
        triggerReaction(reaction: action.reaction)
        return true
    }
}
