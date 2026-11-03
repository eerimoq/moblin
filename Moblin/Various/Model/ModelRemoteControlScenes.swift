import AVFoundation
import Foundation
@preconcurrency import Translation
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
                                   showAllSettings: false,
                                   isPhone: false,
                                   forceSceneSwitchTransition: false,
                                   locationEnabled: false,
                                   workoutActive: false,
                                   numericInput: false,
                                   inactiveVideoSourceSceneIds: [])
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
        if scene.name.isEmpty {
            scene.name = makeUniqueName(name: SettingsScene.baseName, existingNames: database.scenes)
        }
        let newScene = SettingsScene(name: scene.name)
        newScene.id = scene.id
        guard isValidRemoteControlScene(scene: scene,
                                        scenes: database.scenes + [scene],
                                        widgets: database.widgets),
            remoteControlIsValidSceneUpdate(scene: newScene, new: scene)
        else {
            return false
        }
        database.scenes.append(newScene)
        remoteControlApplySceneUpdate(scene: newScene, new: scene)
        remoteControlScenesChanged(sceneId: scene.id)
        return true
    }

    func remoteControlUpdateScene(scene: SettingsScene) -> Bool {
        guard let index = database.scenes.firstIndex(where: { $0.id == scene.id }) else {
            return false
        }
        let oldScene = database.scenes[index]
        var scenes = database.scenes
        scenes[index] = scene
        guard isValidRemoteControlScene(scene: scene, scenes: scenes, widgets: database.widgets),
              remoteControlIsValidSceneUpdate(scene: oldScene, new: scene)
        else {
            return false
        }
        remoteControlApplySceneUpdate(scene: oldScene, new: scene)
        remoteControlScenesChanged(sceneId: scene.id)
        return true
    }

    func remoteControlDeleteScene(id: UUID) -> Bool {
        guard let scene = database.scenes.first(where: { $0.id == id }) else {
            return false
        }
        deleteScene(scene: scene)
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
        guard !database.widgets.contains(where: { $0.id == widget.id }),
              let newWidget = remoteControlMakeWidget(widget: widget),
              isValidName(newWidget, database.widgets + [newWidget], database.widgets)
        else {
            return false
        }
        database.widgets.append(newWidget)
        fixAlertMedias()
        resetSelectedScene(changeScene: false, attachCamera: false)
        if newWidget.type == .text {
            textWidgetTextChanged(widget: newWidget)
        }
        return true
    }

    func remoteControlUpdateWidget(widget: SettingsWidget) -> Bool {
        guard let oldWidget = database.widgets.first(where: { $0.id == widget.id }),
              isValidName(widget, database.widgets, database.widgets),
              remoteControlIsValidWidgetUpdate(widget: oldWidget, new: widget)
        else {
            return false
        }
        let changes = remoteControlApplyWidgetUpdate(widget: oldWidget, new: widget)
        remoteControlWidgetUpdated(widget: oldWidget, changes: changes)
        return true
    }

    func remoteControlDeleteWidget(id: UUID) -> Bool {
        guard database.widgets.contains(where: { $0.id == id }) else {
            return false
        }
        database.widgets.removeAll { $0.id == id }
        removeDeadWidgetsFromScenes()
        resetSelectedScene(changeScene: false)
        remoteControlScenesChanged()
        return true
    }

    func remoteControlReorderWidgets(ids: [UUID]) -> Bool {
        guard let widgets = reorder(items: database.widgets, ids: ids) else {
            return false
        }
        database.widgets = widgets
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
                                         .map { .init(name: $0.name,
                                                      identifier: $0.identifier,
                                                      language: $0.language) })
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
            showAllSettings: database.showAllSettings,
            isPhone: isPhone(),
            forceSceneSwitchTransition: database.forceSceneSwitchTransition,
            locationEnabled: database.location.enabled,
            workoutActive: workoutType != nil,
            numericInput: database.sceneNumericInput,
            inactiveVideoSourceSceneIds: database.scenes.filter { !isSceneVideoSourceActive(scene: $0) }
                .map(\.id)
        )
    }

    func remoteControlGetVideoSourceSnapshot(id: UUID, onCompleted: @escaping (Data?) -> Void) {
        guard let widget = database.widgets.first(where: { $0.id == id }) else {
            onCompleted(nil)
            return
        }
        takeVideoSourcePreviewImage(widget: widget) { image in
            onCompleted(image?.jpegData(compressionQuality: 0.8))
        }
    }

    func remoteControlGetTranslationLanguages(
        onCompleted: @escaping ([RemoteControlTranslationLanguage]) -> Void
    ) {
        guard #available(iOS 26, *) else {
            onCompleted([])
            return
        }
        Task {
            let availability = LanguageAvailability()
            var languages: [RemoteControlTranslationLanguage] = []
            for language in await availability.supportedLanguages {
                switch await availability.status(from: Locale.current.language, to: language) {
                case .installed:
                    languages.append(.init(identifier: language.minimalIdentifier,
                                           name: language.name(),
                                           installed: true))
                case .supported:
                    languages.append(.init(identifier: language.minimalIdentifier,
                                           name: language.name(),
                                           installed: false))
                default:
                    break
                }
            }
            let sorted = languages.sorted { $0.identifier < $1.identifier }
            await MainActor.run {
                onCompleted(sorted)
            }
        }
    }

    func remoteControlSetNumericInput(enabled: Bool) {
        database.sceneNumericInput = enabled
    }

    func remoteControlSetLocationEnabled(enabled: Bool) {
        database.location.enabled = enabled
        reloadLocation()
    }

    func remoteControlSetScoreboardPlayers(players: [SettingsWidgetScoreboardPlayer]) -> Bool {
        guard hasUniqueIds(players),
              players.allSatisfy({ isValidName($0, players, database.scoreboardPlayers) })
        else {
            return false
        }
        database.scoreboardPlayers = players
        sceneUpdated()
        sendScoreboardPlayersToWatch()
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
    }

    private func isValidRemoteControlScene(scene: SettingsScene,
                                           scenes: [SettingsScene],
                                           widgets: [SettingsWidget]) -> Bool
    {
        isValidName(scene, scenes, database.scenes)
            && hasUniqueIds(scene.widgets)
            && !introducesDuplicatedWidgets(scenes: scenes, widgets: widgets)
    }

    private func introducesDuplicatedWidgets(scenes: [SettingsScene], widgets: [SettingsWidget]) -> Bool {
        let before = SceneResolver(scenes: database.scenes, widgets: database.widgets)
        let after = SceneResolver(scenes: scenes, widgets: widgets)
        return scenes.contains { scene in
            let beforeCounts = database.scenes.first(where: { $0.id == scene.id }).map {
                before.resolve($0, includeDisabledSceneWidgets: true).duplicatedWidgetCounts()
            } ?? [:]
            return after.resolve(scene, includeDisabledSceneWidgets: true).duplicatedWidgetCounts()
                .contains { widgetId, count in
                    count > beforeCounts[widgetId, default: 0]
                }
        }
    }

    private func isValidName<T: Named & Identifiable>(_ item: T, _ items: [T], _ oldItems: [T]) -> Bool
        where T.ID == UUID
    {
        if oldItems.first(where: { $0.id == item.id })?.name == item.name {
            return true
        }
        return !item.name.isEmpty && !items.contains { $0.id != item.id && $0.name == item.name }
    }

    private func hasUniqueIds<T: Identifiable>(_ items: [T]) -> Bool where T.ID == UUID {
        Set(items.map(\.id)).count == items.count
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
