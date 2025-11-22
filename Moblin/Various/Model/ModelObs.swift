import UIKit

struct ObsSceneInput: Identifiable {
    var id: UUID = .init()
    var name: String
    var muted: Bool?
}

class QuickButtonObs: ObservableObject {
    var sourceFetchScreenshot = false
    var sourceScreenshotIsFetching = false
    var recording = false
    var audioVolumeLatest: String = ""
    var sceneBeforeSwitchToBrbScene: String?
    @Published var streamingState: ObsOutputState = .stopped
    @Published var recordingState: ObsOutputState = .stopped
    @Published var sceneInputs: [ObsSceneInput] = []
    @Published var audioVolume: String = noValue
    @Published var currentScenePicker: String = ""
    @Published var currentScene: String = ""
    @Published var scenes: [String] = []
    @Published var screenshot: CGImage?
    @Published var streaming = false
    @Published var fixOngoing = false
    @Published var audioDelay: Int = 0

    func startObsSourceScreenshot() {
        screenshot = nil
        sourceFetchScreenshot = true
        sourceScreenshotIsFetching = false
    }

    func stopObsSourceScreenshot() {
        sourceFetchScreenshot = false
    }
}

extension Model {
    func updateObsSourceScreenshot() {
        guard obsQuickButton.sourceFetchScreenshot else {
            return
        }
        guard !obsQuickButton.sourceScreenshotIsFetching else {
            return
        }
        guard !obsQuickButton.currentScene.isEmpty else {
            return
        }
        obsWebSocket?.getSourceScreenshot(name: obsQuickButton.currentScene, onSuccess: { data in
            let screenshot = UIImage(data: data)?.cgImage
            self.obsQuickButton.screenshot = screenshot
            self.obsQuickButton.sourceScreenshotIsFetching = false
        }, onError: { message in
            logger.debug("Failed to update screenshot with error \(message)")
            self.obsQuickButton.screenshot = nil
            self.obsQuickButton.sourceScreenshotIsFetching = false
        })
    }

    func setObsAudioDelay(offset: Int) {
        guard !stream.obsSourceName.isEmpty else {
            return
        }
        obsWebSocket?.setInputAudioSyncOffset(name: stream.obsSourceName, offsetInMs: offset, onSuccess: {
            DispatchQueue.main.async {
                self.updateObsAudioDelay()
            }
        }, onError: { _ in
        })
    }

    func updateObsAudioDelay() {
        guard !stream.obsSourceName.isEmpty else {
            return
        }
        obsWebSocket?.getInputAudioSyncOffset(name: stream.obsSourceName, onSuccess: { offset in
            DispatchQueue.main.async {
                self.obsQuickButton.audioDelay = offset
            }
        }, onError: { _ in
        })
    }

    func isObsConnected() -> Bool {
        return obsWebSocket?.isConnected() ?? false
    }

    func obsConnectionErrorMessage() -> String {
        return obsWebSocket?.connectionErrorMessage ?? ""
    }

    func listObsScenes(updateAudioInputs: Bool = false) {
        obsWebSocket?.getSceneList(onSuccess: { list in
            self.obsQuickButton.currentScenePicker = list.current
            self.obsQuickButton.currentScene = list.current
            self.obsQuickButton.scenes = list.scenes
            if updateAudioInputs {
                self.updateObsAudioInputs(sceneName: list.current)
            }
            self.updateStatusObsText()
        }, onError: { _ in
        })
    }

    func updateObsAudioInputs(sceneName: String) {
        obsWebSocket?.getInputList { inputs in
            self.obsWebSocket?.getSpecialInputs { specialInputs in
                self.obsWebSocket?.getSceneItemList(sceneName: sceneName, onSuccess: { sceneItems in
                    guard !sceneItems.isEmpty else {
                        self.obsQuickButton.sceneInputs = []
                        return
                    }
                    var obsSceneInputs: [ObsSceneInput] = []
                    for input in inputs {
                        if specialInputs.mics().contains(input) {
                            obsSceneInputs.append(ObsSceneInput(name: input))
                        } else if sceneItems.contains(where: { $0.sourceName == input }) {
                            if sceneItems.first(where: { $0.sourceName == input })?.sceneItemEnabled == true {
                                obsSceneInputs.append(ObsSceneInput(name: input))
                            }
                        }
                    }
                    self.obsWebSocket?.getInputMuteBatch(
                        inputNames: obsSceneInputs.map { $0.name },
                        onSuccess: { muteds in
                            guard muteds.count == obsSceneInputs.count else {
                                self.obsQuickButton.sceneInputs = []
                                return
                            }
                            for (i, muted) in muteds.enumerated() {
                                obsSceneInputs[i].muted = muted
                            }
                            self.obsQuickButton.sceneInputs = obsSceneInputs
                        }, onError: { _ in
                            self.obsQuickButton.sceneInputs = []
                        }
                    )
                }, onError: { _ in
                    self.obsQuickButton.sceneInputs = []
                })
            } onError: { _ in
                self.obsQuickButton.sceneInputs = []
            }
        } onError: { _ in
            self.obsQuickButton.sceneInputs = []
        }
    }

    func setObsScene(name: String) {
        obsWebSocket?.setCurrentProgramScene(name: name, onSuccess: {
            self.obsQuickButton.currentScene = name
            self.updateObsAudioInputs(sceneName: name)
        }, onError: { message in
            self.makeErrorToast(title: String(localized: "Failed to set OBS scene to \(name)"),
                                subTitle: message)
        })
    }

    func updateObsStatus() {
        guard isObsConnected() else {
            obsQuickButton.audioVolumeLatest = noValue
            return
        }
        obsWebSocket?.getStreamStatus(onSuccess: { state in
            self.obsWebsocketStreamStatusChanged(active: state.active, state: state.state)
        }, onError: { _ in
            self.obsWebsocketStreamStatusChanged(active: false, state: nil)
        })
        obsWebSocket?.getRecordStatus(onSuccess: { status in
            self.obsWebsocketRecordStatusChanged(active: status.active, state: nil)
        }, onError: { _ in
            self.obsWebsocketRecordStatusChanged(active: false, state: nil)
        })
        listObsScenes()
    }

    private func isStreamLikelyBroken(now: ContinuousClock.Instant) -> Bool {
        defer {
            previousSrtDroppedPacketsTotal = media.srtDroppedPacketsTotal
        }
        if streamState == .disconnected {
            return true
        }
        if media.srtDroppedPacketsTotal > previousSrtDroppedPacketsTotal {
            streamBecameBrokenTime = now
            return true
        }
        if let streamBecameBrokenTime {
            if streamBecameBrokenTime.duration(to: now) < .seconds(15) {
                return true
            } else if obsQuickButton.currentScene != stream.obsBrbScene {
                return true
            }
        }
        if stream.obsBrbSceneVideoSourceBroken, let scene = getSelectedScene() {
            switch scene.videoSource.cameraPosition {
            case .srtla:
                if let srtlaStream = getSrtlaStream(id: scene.videoSource.srtlaCameraId) {
                    if ingests.srtla?.isStreamConnected(streamId: srtlaStream.streamId) == false {
                        streamBecameBrokenTime = now
                        return true
                    }
                }
            case .rtmp:
                if let rtmpStream = getRtmpStream(id: scene.videoSource.rtmpCameraId) {
                    if ingests.rtmp?.isStreamConnected(streamKey: rtmpStream.streamKey) == false {
                        streamBecameBrokenTime = now
                        return true
                    }
                }
            default:
                break
            }
        }
        streamBecameBrokenTime = nil
        return false
    }

    func updateObsSceneSwitcher(now: ContinuousClock.Instant) {
        guard isLive, !stream.obsBrbScene.isEmpty, !obsQuickButton.currentScene.isEmpty, isObsConnected() else {
            return
        }
        if isStreamLikelyBroken(now: now) {
            if obsQuickButton.currentScene != stream.obsBrbScene {
                if !stream.obsMainScene.isEmpty {
                    obsQuickButton.sceneBeforeSwitchToBrbScene = stream.obsMainScene
                } else {
                    obsQuickButton.sceneBeforeSwitchToBrbScene = obsQuickButton.currentScene
                }
                makeStreamLikelyBrokenToast(scene: stream.obsBrbScene)
                setObsScene(name: stream.obsBrbScene)
            }
        } else if let obsSceneBeforeSwitchToBrbScene = obsQuickButton.sceneBeforeSwitchToBrbScene {
            if obsQuickButton.currentScene == stream.obsBrbScene {
                makeStreamLikelyWorkingToast(scene: obsSceneBeforeSwitchToBrbScene)
                setObsScene(name: obsSceneBeforeSwitchToBrbScene)
            } else if obsQuickButton.currentScene == obsSceneBeforeSwitchToBrbScene {
                obsQuickButton.sceneBeforeSwitchToBrbScene = nil
            }
        }
    }

    private func makeStreamLikelyBrokenToast(scene: String) {
        makeErrorToast(
            title: String(localized: "😠 Stream likely broken 😠"),
            subTitle: String(localized: "Trying to switch OBS scene to \(scene)")
        )
    }

    private func makeStreamLikelyWorkingToast(scene: String) {
        makeToast(
            title: String(localized: "🥳 Stream likely working 🥳"),
            subTitle: String(localized: "Trying to switch OBS scene to \(scene)")
        )
    }

    func reloadObsWebSocket() {
        obsWebSocket?.stop()
        obsWebSocket = nil
        guard isObsRemoteControlConfigured() else {
            return
        }
        guard let url = URL(string: stream.obsWebSocketUrl) else {
            return
        }
        obsWebSocket = ObsWebSocket(
            url: url,
            password: stream.obsWebSocketPassword,
            delegate: self
        )
        obsWebSocket!.start()
    }

    func obsWebSocketEnabledUpdated() {
        reloadObsWebSocket()
    }

    func obsWebSocketUrlUpdated() {
        reloadObsWebSocket()
    }

    func obsWebSocketPasswordUpdated() {
        reloadObsWebSocket()
    }

    func obsStartStream() {
        obsWebSocket?.startStream(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to start OBS stream"),
                                    subTitle: message)
            }
        })
    }

    func obsStopStream() {
        obsWebSocket?.stopStream(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to stop OBS stream"),
                                    subTitle: message)
            }
        })
    }

    func obsStartRecording() {
        obsWebSocket?.startRecord(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to start OBS recording"),
                                    subTitle: message)
            }
        })
    }

    func obsStopRecording() {
        obsWebSocket?.stopRecord(onSuccess: {}, onError: { message in
            DispatchQueue.main.async {
                self.makeErrorToast(title: String(localized: "Failed to stop OBS recording"),
                                    subTitle: message)
            }
        })
    }

    func obsFixStream() {
        guard let obsWebSocket else {
            return
        }
        obsQuickButton.fixOngoing = true
        obsWebSocket.setInputSettings(inputName: stream.obsSourceName,
                                      onSuccess: {
                                          self.obsQuickButton.fixOngoing = false
                                      }, onError: { message in
                                          self.obsQuickButton.fixOngoing = false
                                          DispatchQueue.main.async {
                                              self.makeErrorToast(
                                                  title: String(localized: "Failed to fix OBS input"),
                                                  subTitle: message
                                              )
                                          }
                                      })
    }

    func obsMuteAudio(inputName: String, muted: Bool) {
        guard let obsWebSocket else {
            return
        }
        obsWebSocket.setInputMute(inputName: inputName,
                                  muted: muted,
                                  onSuccess: {}, onError: { _ in
                                  })
    }

    func startObsAudioVolume() {
        obsQuickButton.audioVolumeLatest = noValue
        obsWebSocket?.startAudioVolume()
    }

    func stopObsAudioVolume() {
        obsWebSocket?.stopAudioVolume()
    }

    func updateObsAudioVolume() {
        if obsQuickButton.audioVolumeLatest != obsQuickButton.audioVolume {
            obsQuickButton.audioVolume = obsQuickButton.audioVolumeLatest
        }
    }

    func isShowingStatusObs() -> Bool {
        return database.show.obsStatus && isObsRemoteControlConfigured()
    }

    private func statusObsText() -> String {
        if !isObsRemoteControlConfigured() {
            return String(localized: "Not configured")
        } else if isObsConnected() {
            if obsQuickButton.streaming && obsQuickButton.recording {
                return "\(obsQuickButton.currentScene) (Streaming, Recording)"
            } else if obsQuickButton.streaming {
                return "\(obsQuickButton.currentScene) (Streaming)"
            } else if obsQuickButton.recording {
                return "\(obsQuickButton.currentScene) (Recording)"
            } else {
                return obsQuickButton.currentScene
            }
        } else {
            return obsConnectionErrorMessage()
        }
    }

    func updateStatusObsText() {
        statusTopLeft.statusObsText = statusObsText()
    }

    func isObsRemoteControlConfigured() -> Bool {
        return stream.obsWebSocketEnabled && stream.obsWebSocketUrl != "" && stream.obsWebSocketPassword != ""
    }
}

extension Model: ObsWebsocketDelegate {
    func obsWebsocketConnected() {
        updateObsStatus()
        updateStatusObsText()
    }

    func obsWebsocketSceneChanged(sceneName: String) {
        obsQuickButton.currentScenePicker = sceneName
        obsQuickButton.currentScene = sceneName
        updateObsAudioInputs(sceneName: sceneName)
        updateStatusObsText()
    }

    func obsWebsocketInputMuteStateChangedEvent(inputName: String, muted: Bool) {
        obsQuickButton.sceneInputs = obsQuickButton.sceneInputs.map { input in
            var input = input
            if input.name == inputName {
                input.muted = muted
            }
            return input
        }
        updateStatusObsText()
    }

    func obsWebsocketStreamStatusChanged(active: Bool, state: ObsOutputState?) {
        obsQuickButton.streaming = active
        if let state {
            obsQuickButton.streamingState = state
        } else if active {
            obsQuickButton.streamingState = .started
        } else {
            obsQuickButton.streamingState = .stopped
        }
        updateStatusObsText()
    }

    func obsWebsocketRecordStatusChanged(active: Bool, state: ObsOutputState?) {
        obsQuickButton.recording = active
        if let state {
            obsQuickButton.recordingState = state
        } else if active {
            obsQuickButton.recordingState = .started
        } else {
            obsQuickButton.recordingState = .stopped
        }
        updateStatusObsText()
    }

    func obsWebsocketAudioVolume(volumes: [ObsAudioInputVolume]) {
        guard let volume = volumes.first(where: { $0.name == self.stream.obsSourceName }) else {
            obsQuickButton.audioVolumeLatest =
                String(localized: "Source \(stream.obsSourceName) not found")
            return
        }
        var values: [String] = []
        for volume in volume.volumes {
            if volume.isInfinite {
                values.append(String(localized: "Muted"))
            } else {
                values.append(String(localized: "\(formatOneDecimal(volume)) dB"))
            }
        }
        obsQuickButton.audioVolumeLatest = values.joined(separator: ", ")
    }
}
