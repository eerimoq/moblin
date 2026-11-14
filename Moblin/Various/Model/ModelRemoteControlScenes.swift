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
                                   showAllSettings: false,
                                   isPhone: false,
                                   forceSceneSwitchTransition: false,
                                   workoutActive: false,
                                   inactiveVideoSourceSceneIds: [],
                                   canvasSize: .init(width: 1920, height: 1080))
    }
}

extension Model {
    func remoteControlGetScenes() -> [SettingsScene] {
        database.scenes
    }

    func remoteControlGetWidgets(secrets: Bool) -> [SettingsWidget] {
        guard !secrets else {
            return database.widgets
        }
        return database.widgets.compactMap {
            let widget = $0.deepCopy()
            widget?.removeSecrets()
            return widget
        }
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
        let cameras = remoteControlCameras()
        guard isValidRemoteControlScene(scene: scene, scenes: database.scenes + [scene], database: database),
              isValidRemoteControlSceneUpdate(
                  scene: newScene,
                  new: scene,
                  database: database,
                  cameras: cameras
              )
        else {
            return false
        }
        database.scenes.append(newScene)
        remoteControlApplySceneUpdate(scene: newScene, new: scene, creating: true)
        return true
    }

    func remoteControlUpdateScene(scene: SettingsScene) -> Bool {
        guard let index = database.scenes.firstIndex(where: { $0.id == scene.id }) else {
            return false
        }
        let oldScene = database.scenes[index]
        var scenes = database.scenes
        scenes[index] = scene
        let cameras = remoteControlCameras()
        guard isValidRemoteControlScene(scene: scene, scenes: scenes, database: database),
              isValidRemoteControlSceneUpdate(
                  scene: oldScene,
                  new: scene,
                  database: database,
                  cameras: cameras
              )
        else {
            return false
        }
        remoteControlApplySceneUpdate(scene: oldScene, new: scene, creating: false)
        return true
    }

    func remoteControlDeleteScene(id: UUID) -> Bool {
        guard let scene = database.findScene(id: id) else {
            return false
        }
        deleteScene(scene: scene)
        return true
    }

    func remoteControlCreateWidget(widget: SettingsWidget, sceneIds: [UUID], secrets: Bool) -> Bool {
        if !secrets {
            widget.keepSecrets(from: SettingsWidget(name: ""))
        }
        guard !database.widgets.contains(where: { $0.id == widget.id }),
              let newWidget = remoteControlMakeWidget(widget: widget),
              isValidRemoteControlName(newWidget, database.widgets + [newWidget], database.widgets),
              isValidRemoteControlWidgetScenes(widget: newWidget, sceneIds: sceneIds, database: database)
        else {
            return false
        }
        widgetWizardCreate(type: newWidget.type,
                           name: newWidget.name,
                           widget: newWidget,
                           scenes: database.scenes.filter { sceneIds.contains($0.id) })
        return true
    }

    func remoteControlUpdateWidget(widget: SettingsWidget, secrets: Bool) -> Bool {
        guard let oldWidget = database.findWidget(id: widget.id) else {
            return false
        }
        if !secrets {
            widget.keepSecrets(from: oldWidget)
        }
        guard isValidRemoteControlName(widget, database.widgets, database.widgets),
              remoteControlApplyWidgetUpdate(widget: oldWidget, new: widget, creating: false)
        else {
            return false
        }
        return true
    }

    func remoteControlDeleteWidget(id: UUID) -> Bool {
        guard let widget = database.findWidget(id: id) else {
            return false
        }
        deleteWidget(widget: widget)
        return true
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
        let canvasSize = media.getCanvasSize()
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
            workoutActive: workoutType != nil,
            inactiveVideoSourceSceneIds: database.scenes.filter { !isSceneVideoSourceActive(scene: $0) }
                .map(\.id),
            canvasSize: RemoteControlSize(width: canvasSize.width, height: canvasSize.height)
        )
    }

    func remoteControlGetVideoSourceSnapshot(id: UUID, onCompleted: @escaping (Data?) -> Void) {
        guard let widget = database.findWidget(id: id) else {
            onCompleted(nil)
            return
        }
        takeVideoSourcePreviewImage(widget: widget) { image in
            onCompleted(image?.jpegData(compressionQuality: 0.8))
        }
    }

    func remoteControlSetScoreboardPlayers(players: [SettingsWidgetScoreboardPlayer]) -> Bool {
        guard hasUniqueRemoteControlIds(players),
              players.allSatisfy({ isValidRemoteControlName($0, players, database.scoreboardPlayers) })
        else {
            return false
        }
        database.scoreboardPlayers = players
        scoreboardPlayersChanged()
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
}
