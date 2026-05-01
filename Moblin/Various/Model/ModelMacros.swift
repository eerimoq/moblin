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
        case .delay:
            executeNext = executeDelay(currentMacro: currentMacro,
                                       action: action,
                                       macro: macro)
        case .macro:
            executeNext = executeMacro(action: action, macro: macro)
        case nil:
            executeNext = true
        }
        if executeNext {
            executeNextAction(macro: macro)
        }
    }

    private func executeEnableScene(action: SettingsMacrosAction) -> Bool {
        executeEnableDisableScene(action: action, enabled: true)
        return true
    }

    private func executeDisableScene(action: SettingsMacrosAction) -> Bool {
        executeEnableDisableScene(action: action, enabled: false)
        return true
    }

    private func executeScene(action: SettingsMacrosAction) -> Bool {
        if let sceneId = action.sceneId {
            selectScene(id: sceneId)
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

    private func executeEnableDisableScene(action: SettingsMacrosAction, enabled: Bool) {
        guard let scene = getScene(id: action.sceneId) else {
            return
        }
        scene.enabled = enabled
        if getSelectedScene() === scene {
            resetSelectedScene()
        } else {
            sceneSelector.sceneIndex += 0
        }
    }
}
