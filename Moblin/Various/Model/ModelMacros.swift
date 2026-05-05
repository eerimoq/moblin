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
        for macro in macro.stack {
            macro.timer.stop()
        }
        macro.stack.removeAll()
    }

    func toggleMacroStartStop(id: UUID) {
        guard let macro = database.macros.macros.first(where: { $0.id == id }) else {
            return
        }
        if macro.running {
            stopMacro(macro: macro)
        } else {
            startMacro(macro: macro)
        }
    }

    private func executeNextAction(macro: SettingsMacrosMacro) {
        guard let currentMacro = macro.stack.last else {
            return
        }
        guard currentMacro.nextActionIndex < currentMacro.actions.count else {
            currentMacro.running = false
            macro.stack.removeLast()
            executeNextAction(macro: macro)
            return
        }
        let action = currentMacro.actions[currentMacro.nextActionIndex]
        currentMacro.nextActionIndex += 1
        let executeNext: Bool
        switch action.function {
        case .enableScene:
            executeNext = executeEnableScene(action: action)
        case .disableScene:
            executeNext = executeDisableScene(action: action)
        case .scene:
            executeNext = executeScene(action: action)
        case .enableDisableScenes:
            executeNext = executeEnableDisableScenes(action: action)
        case .autoSceneSwitcher:
            executeNext = executeAutoSceneSwitcher(action: action)
        case .zoom:
            executeNext = executeZoom(action: action)
        case .gimbalPreset:
            executeNext = executeGimbalPreset(action: action)
        case .delay:
            executeNext = executeDelay(currentMacro: currentMacro,
                                       action: action,
                                       macro: macro)
        case .macro:
            executeNext = executeMacro(action: action, macro: macro)
        case .djiDevices:
            executeNext = executeDjiDevices(action: action)
        case nil:
            executeNext = true
        }
        if executeNext {
            executeNextAction(macro: macro)
        }
    }

    private func executeEnableScene(action: SettingsMacrosAction) -> Bool {
        return executeEnableDisableScene(action: action, enabled: true)
    }

    private func executeDisableScene(action: SettingsMacrosAction) -> Bool {
        return executeEnableDisableScene(action: action, enabled: false)
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

    private func executeDelay(currentMacro _: SettingsMacrosMacro,
                              action: SettingsMacrosAction,
                              macro: SettingsMacrosMacro) -> Bool
    {
        macro.timer.startSingleShot(timeout: action.delay) {
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

    private func executeDjiDevices(action: SettingsMacrosAction) -> Bool {
        reloadDjiDevices(enabledDeviceIds: action.djiDevices)
        return true
    }

    private func executeEnableDisableScene(action: SettingsMacrosAction, enabled: Bool) -> Bool {
        getScene(id: action.sceneId)?.enabled = enabled
        sceneSelector.trigger += 1
        return true
    }
}
