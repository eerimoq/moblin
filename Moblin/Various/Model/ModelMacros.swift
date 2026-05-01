import Foundation

extension Model {
    func startMacro(macro: SettingsMacrosMacro) {
        guard !macro.running else {
            return
        }
        macro.running = true
        macro.nextActionIndex = 0
        executeNextAction(macro: macro)
    }

    func stopMacro(macro: SettingsMacrosMacro) {
        guard macro.running else {
            return
        }
        macro.running = false
        macro.timer.stop()
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
        guard macro.nextActionIndex < macro.actions.count else {
            macro.running = false
            return
        }
        let action = macro.actions[macro.nextActionIndex]
        macro.nextActionIndex += 1
        let executeNext: Bool
        switch action.function {
        case .enableScene:
            executeNext = executeEnableScene(action: action)
        case .disableScene:
            executeNext = executeDisableScene(action: action)
        case .scene:
            executeNext = executeScene(action: action)
        case .delay:
            executeNext = executeDelay(macro: macro, action: action)
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

    private func executeDelay(macro: SettingsMacrosMacro, action: SettingsMacrosAction) -> Bool {
        macro.timer.startSingleShot(timeout: action.delay) {
            self.executeNextAction(macro: macro)
        }
        return false
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
