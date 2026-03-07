import Foundation

class AutoCameraSwitcherProvider: ObservableObject {
    fileprivate let director = AutoCameraDirector()
    fileprivate var configuredSwitcherId: UUID?
    @Published var currentSwitcherId: UUID?
}

extension Model {
    func setAutoCameraSwitcher(id: UUID?) {
        database.autoCameraSwitchers.switcherId = id
        autoCameraSwitcher.configuredSwitcherId = nil
        autoCameraSwitcher.director.reset()
    }

    func deleteAutoCameraSwitchers(offsets: IndexSet) {
        database.autoCameraSwitchers.switchers.remove(atOffsets: offsets)
        if !database.autoCameraSwitchers.switchers
            .contains(where: { $0.id == autoCameraSwitcher.currentSwitcherId })
        {
            autoCameraSwitcher.currentSwitcherId = nil
            setAutoCameraSwitcher(id: nil)
        }
    }

    func updateAutoCameraSwitcher(now: ContinuousClock.Instant) {
        guard let switcherId = autoCameraSwitcher.currentSwitcherId else {
            return
        }
        guard let switcher = database.autoCameraSwitchers.switchers
            .first(where: { $0.id == switcherId })
        else {
            return
        }
        guard switcher.enabled else {
            return
        }
        if autoCameraSwitcher.configuredSwitcherId != switcherId {
            autoCameraSwitcher.director.configure(settings: switcher)
            autoCameraSwitcher.configuredSwitcherId = switcherId
        }
        let micLevels = collectMicLevels(switcher: switcher)
        if let sceneId = autoCameraSwitcher.director.update(micLevels: micLevels, now: now) {
            if enabledScenes.contains(where: { $0.id == sceneId }) {
                selectScene(id: sceneId)
            }
        }
    }

    private func collectMicLevels(switcher: SettingsAutoCameraSwitcher) -> [String: Float] {
        var levels: [String: Float] = [:]
        for speaker in switcher.speakers {
            for micId in speaker.microphoneIds {
                let level = audio.level.level
                if !level.isNaN, level != .infinity {
                    levels[micId] = level
                }
            }
        }
        return levels
    }
}
