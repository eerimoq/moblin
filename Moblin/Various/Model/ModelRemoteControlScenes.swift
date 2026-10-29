import AVFoundation
import Foundation
import UIKit

extension RemoteControlEditorOptions {
    static func empty() -> RemoteControlEditorOptions {
        RemoteControlEditorOptions(fonts: [],
                                   luts: [],
                                   scoreboardPlayers: [],
                                   webRemote: .init(enabled: false, port: 0, deviceName: "", addresses: []),
                                   workoutDevices: [],
                                   streamDeckLayouts: [],
                                   appleVoices: [],
                                   showAllSettings: false)
    }
}

extension Model {
    func remoteControlGetScenes() -> [SettingsScene] {
        database.scenes
    }

    func remoteControlGetWidgets() -> [SettingsWidget] {
        database.widgets
    }

    func remoteControlCreateScene(scene: SettingsScene) -> Bool {
        guard !database.scenes.contains(where: { $0.id == scene.id }) else {
            return false
        }
        database.scenes.append(scene)
        removeDeadWidgetsFromScenes()
        remoteControlScenesChanged(sceneId: scene.id)
        return true
    }

    func remoteControlUpdateScene(scene: SettingsScene) -> Bool {
        guard let index = database.scenes.firstIndex(where: { $0.id == scene.id }) else {
            return false
        }
        database.scenes[index] = scene
        removeDeadWidgetsFromScenes()
        remoteControlScenesChanged(sceneId: scene.id)
        return true
    }

    func remoteControlDeleteScene(id: UUID) -> Bool {
        guard database.scenes.contains(where: { $0.id == id }) else {
            return false
        }
        database.scenes.removeAll { $0.id == id }
        remoteControlScenesChanged(sceneId: id)
        return true
    }

    func remoteControlReorderScenes(ids: [UUID]) -> Bool {
        guard let scenes = reorder(items: database.scenes, ids: ids) else {
            return false
        }
        database.scenes = scenes
        remoteControlScenesChanged(sceneId: nil)
        return true
    }

    func remoteControlCreateWidget(widget: SettingsWidget) -> Bool {
        guard !database.widgets.contains(where: { $0.id == widget.id }) else {
            return false
        }
        database.widgets.append(widget)
        remoteControlWidgetsChanged(widget: widget)
        return true
    }

    func remoteControlUpdateWidget(widget: SettingsWidget) -> Bool {
        guard let index = database.widgets.firstIndex(where: { $0.id == widget.id }) else {
            return false
        }
        database.widgets[index] = widget
        remoteControlWidgetsChanged(widget: widget)
        return true
    }

    func remoteControlDeleteWidget(id: UUID) -> Bool {
        guard database.widgets.contains(where: { $0.id == id }) else {
            return false
        }
        database.widgets.removeAll { $0.id == id }
        removeDeadWidgetsFromScenes()
        resetSelectedScene(changeScene: false)
        storeSettings()
        remoteControlScenesChanged()
        return true
    }

    func remoteControlReorderWidgets(ids: [UUID]) -> Bool {
        guard let widgets = reorder(items: database.widgets, ids: ids) else {
            return false
        }
        database.widgets = widgets
        storeSettings()
        remoteControlScenesChanged()
        return true
    }

    func remoteControlGetWidgetImage(id: UUID) -> Data? {
        guard database.widgets.contains(where: { $0.id == id && $0.type == .image }) else {
            return nil
        }
        return imageStorage.tryRead(id: id)
    }

    func remoteControlGetAlertMedia(id: UUID) -> Data? {
        let gallery = database.alertsMediaGallery
        if let image = gallery.bundledImages.first(where: { $0.id == id }) {
            guard let url = Bundle.main.url(forResource: "Alerts.bundle/\(image.name)", withExtension: "gif")
            else {
                return nil
            }
            return try? Data(contentsOf: url)
        }
        if let sound = gallery.bundledSounds.first(where: { $0.id == id }) {
            guard let url = Bundle.main.url(forResource: "Alerts.bundle/\(sound.name)", withExtension: "mp3")
            else {
                return nil
            }
            return try? Data(contentsOf: url)
        }
        guard gallery.customImages.contains(where: { $0.id == id })
            || gallery.customSounds.contains(where: { $0.id == id })
        else {
            return nil
        }
        return alertMediaStorage.tryRead(id: id)
    }

    func remoteControlGetEditorOptions() -> RemoteControlEditorOptions {
        let web = database.remoteControl.web
        var addresses: [String] = []
        if !web.deviceName.isEmpty {
            addresses.append(makeMdnsHostname(deviceName: web.deviceName))
        }
        for status in statusOther.ipStatuses where status.ipType == .ipv4 {
            if status.interfaceType == .wifi || status.interfaceType == .wiredEthernet {
                addresses.append(status.ip)
            }
        }
        let appleVoices = Dictionary(grouping: AVSpeechSynthesisVoice.speechVoices()) {
            String($0.language.prefix(2))
        }
        .map { language, voices in
            RemoteControlAppleVoices(language: language,
                                     voices: voices
                                         .map { .init(name: $0.name, identifier: $0.identifier) })
        }
        .sorted { $0.language < $1.language }
        return RemoteControlEditorOptions(
            fonts: UIFont.familyNames.sorted().map {
                RemoteControlFontFamily(family: $0, styles: UIFont.fontNames(forFamilyName: $0))
            },
            luts: database.color.allLuts().map { .init(id: $0.id, name: $0.name) },
            scoreboardPlayers: database.scoreboardPlayers,
            webRemote: .init(
                enabled: web.enabled,
                port: web.port,
                deviceName: web.deviceName,
                addresses: addresses
            ),
            workoutDevices: database.workoutDevices.devices.map { .init(id: $0.id, name: $0.name) },
            streamDeckLayouts: database.streamDecks.layouts.map { .init(id: $0.id, name: $0.name) },
            appleVoices: appleVoices,
            showAllSettings: database.showAllSettings
        )
    }

    func remoteControlSetScoreboardPlayers(players: [SettingsWidgetScoreboardPlayer]) -> Bool {
        guard Set(players.map(\.id)).count == players.count else {
            return false
        }
        database.scoreboardPlayers = players
        sendScoreboardPlayersToWatch()
        storeSettings()
        return true
    }

    func remoteControlGetAlertsMediaGallery() -> SettingsAlertsMediaGallery {
        database.alertsMediaGallery
    }

    func remoteControlGetVideoSources() -> [RemoteControlVideoSource] {
        videoSources.all().map { camera in
            var videoSource = SettingsVideoSource()
            videoSource.updateCameraId(settingsCameraId: cameraIdToSettingsCameraId(cameraId: camera.id))
            return RemoteControlVideoSource(id: camera.id,
                                            name: camera.name,
                                            position: videoSource.cameraPosition)
        }
    }

    func remoteControlDeleteAlertMedia(id: UUID) -> Bool {
        let gallery = database.alertsMediaGallery
        guard gallery.customImages.contains(where: { $0.id == id })
            || gallery.customSounds.contains(where: { $0.id == id })
        else {
            return false
        }
        gallery.customImages.removeAll { $0.id == id }
        gallery.customSounds.removeAll { $0.id == id }
        alertMediaStorage.remove(id: id)
        fixAlertMedias()
        storeSettings()
        return true
    }

    private func remoteControlScenesChanged(sceneId: UUID?) {
        let selectedSceneId = sceneSelector.selectedSceneId
        if findEnabledScene(id: selectedSceneId) == nil {
            sceneSelector.sceneIndex = 0
            resetSelectedScene()
        } else {
            sceneSelector.sceneIndex = findEnabledSceneIndex(id: selectedSceneId) ?? 0
            sceneUpdated(attachCamera: sceneId == selectedSceneId)
            if sceneId == selectedSceneId {
                switchMicIfNeededAfterSceneSwitch()
            }
        }
        storeSettings()
    }

    private func remoteControlWidgetsChanged(widget: SettingsWidget) {
        fixAlertMedias()
        resetSelectedScene(changeScene: false, attachCamera: isCaptureDeviceWidget(widget: widget))
        switch widget.type {
        case .text:
            textWidgetTextChanged(widget: widget)
        case .wheelOfLuck:
            updateWheelOfLuckEffect(widget: widget)
        default:
            break
        }
        storeSettings()
    }

    private func reorder<T: Identifiable>(items: [T], ids: [UUID]) -> [T]? where T.ID == UUID {
        guard ids.count == items.count, Set(ids).count == ids.count else {
            return nil
        }
        var reordered: [T] = []
        for id in ids {
            guard let item = items.first(where: { $0.id == id }) else {
                return nil
            }
            reordered.append(item)
        }
        return reordered
    }
}
