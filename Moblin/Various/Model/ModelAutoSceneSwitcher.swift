import Foundation

class AutoSceneSwitcherProvider: ObservableObject {
    fileprivate var switchTime: ContinuousClock.Instant?
    fileprivate var sceneIds: [UUID] = []
    fileprivate var currentSwitcherSceneId: UUID?
    @Published var currentSwitcherId: UUID?
}

extension Model {
    func setAutoSceneSwitcher(id: UUID?) {
        database.autoSceneSwitchers.switcherId = id
        autoSceneSwitcher.switchTime = .now
        autoSceneSwitcher.sceneIds.removeAll()
        remoteControlStreamer?.stateChanged(state: .init(autoSceneSwitcher: .init(id: id)))
    }

    func deleteAutoSceneSwitchers(offsets: IndexSet) {
        database.autoSceneSwitchers.switchers.remove(atOffsets: offsets)
        if !database.autoSceneSwitchers.switchers.contains(where: { $0.id == autoSceneSwitcher.currentSwitcherId }) {
            autoSceneSwitcher.currentSwitcherId = nil
            setAutoSceneSwitcher(id: nil)
        }
    }

    func updateAutoSceneSwitcher(now: ContinuousClock.Instant, forceSwitch: Bool = false) {
        guard let switcherId = autoSceneSwitcher.currentSwitcherId else {
            return
        }
        if let switchTime = autoSceneSwitcher.switchTime, !forceSwitch {
            guard now > switchTime else {
                return
            }
        }
        guard let autoSwitcher = database.autoSceneSwitchers.switchers.first(where: { $0.id == switcherId }) else {
            return
        }
        fillAutoSceneSwitcherIfNeeded(autoSwitcher: autoSwitcher)
        if !trySwitchToNextScene(autoSwitcher: autoSwitcher, now: now) {
            fillAutoSceneSwitcherIfNeeded(autoSwitcher: autoSwitcher)
            if !trySwitchToNextScene(autoSwitcher: autoSwitcher, now: now) {
                logger.info("No scene to auto switch to")
            }
        }
    }

    private func fillAutoSceneSwitcherIfNeeded(autoSwitcher: SettingsAutoSceneSwitcher) {
        if autoSceneSwitcher.sceneIds.isEmpty {
            autoSceneSwitcher.sceneIds = autoSwitcher.scenes.map { $0.id }.reversed()
            if autoSwitcher.shuffle {
                autoSceneSwitcher.sceneIds.shuffle()
                if autoSceneSwitcher.sceneIds.last == autoSceneSwitcher.currentSwitcherSceneId {
                    if let switcherSceneId = autoSceneSwitcher.sceneIds.popLast() {
                        autoSceneSwitcher.sceneIds.insert(switcherSceneId, at: 0)
                    }
                }
            }
        }
    }

    private func trySwitchToNextScene(autoSwitcher: SettingsAutoSceneSwitcher, now: ContinuousClock.Instant) -> Bool {
        while let switcherSceneId = autoSceneSwitcher.sceneIds.popLast() {
            guard let switcherScene = autoSwitcher.scenes.first(where: { $0.id == switcherSceneId }) else {
                continue
            }
            guard let sceneId = switcherScene.sceneId else {
                continue
            }
            guard enabledScenes.contains(where: { $0.id == sceneId }) else {
                continue
            }
            guard isSceneVideoSourceActive(sceneId: sceneId) else {
                continue
            }
            selectScene(id: sceneId)
            autoSceneSwitcher.switchTime = now + .seconds(switcherScene.time)
            autoSceneSwitcher.currentSwitcherSceneId = switcherSceneId
            return true
        }
        return false
    }

    func updateAutoSceneSwitcherVideoSourceDisconnected() {
        guard autoSceneSwitcher.currentSwitcherId != nil else {
            return
        }
        guard let currentSceneId = autoSceneSwitcher.currentSwitcherSceneId else {
            return
        }
        guard !isSceneVideoSourceActive(sceneId: currentSceneId) else {
            return
        }
        updateAutoSceneSwitcher(now: .now, forceSwitch: true)
    }

    func updateAutoSceneSwitcherButtonState() {
        var isOn = false
        if database.autoSceneSwitchers.switcherId != nil {
            isOn = true
        }
        if showingPanel == .autoSceneSwitcher {
            isOn = true
        }
        setGlobalButtonState(type: .autoSceneSwitcher, isOn: isOn)
        updateQuickButtonStates()
    }
}
