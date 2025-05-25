import UIKit

struct ObsSceneInput: Identifiable {
    var id: UUID = .init()
    var name: String
    var muted: Bool?
}

extension Model {
    func startObsSourceScreenshot() {
        obsScreenshot = nil
        obsSourceFetchScreenshot = true
        obsSourceScreenshotIsFetching = false
    }

    func stopObsSourceScreenshot() {
        obsSourceFetchScreenshot = false
    }

    func updateObsSourceScreenshot() {
        guard obsSourceFetchScreenshot else {
            return
        }
        guard !obsSourceScreenshotIsFetching else {
            return
        }
        guard !obsCurrentScene.isEmpty else {
            return
        }
        obsWebSocket?.getSourceScreenshot(name: obsCurrentScene, onSuccess: { data in
            let screenshot = UIImage(data: data)?.cgImage
            self.obsScreenshot = screenshot
            self.obsSourceScreenshotIsFetching = false
        }, onError: { message in
            logger.debug("Failed to update screenshot with error \(message)")
            self.obsScreenshot = nil
            self.obsSourceScreenshotIsFetching = false
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
                self.obsAudioDelay = offset
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
            self.obsCurrentScenePicker = list.current
            self.obsCurrentScene = list.current
            self.obsScenes = list.scenes
            if updateAudioInputs {
                self.updateObsAudioInputs(sceneName: list.current)
            }
        }, onError: { _ in
        })
    }

    func updateObsAudioInputs(sceneName: String) {
        obsWebSocket?.getInputList { inputs in
            self.obsWebSocket?.getSpecialInputs { specialInputs in
                self.obsWebSocket?.getSceneItemList(sceneName: sceneName, onSuccess: { sceneItems in
                    guard !sceneItems.isEmpty else {
                        self.obsSceneInputs = []
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
                                self.obsSceneInputs = []
                                return
                            }
                            for (i, muted) in muteds.enumerated() {
                                obsSceneInputs[i].muted = muted
                            }
                            self.obsSceneInputs = obsSceneInputs
                        }, onError: { _ in
                            self.obsSceneInputs = []
                        }
                    )
                }, onError: { _ in
                    self.obsSceneInputs = []
                })
            } onError: { _ in
                self.obsSceneInputs = []
            }
        } onError: { _ in
            self.obsSceneInputs = []
        }
    }

    func setObsScene(name: String) {
        obsWebSocket?.setCurrentProgramScene(name: name, onSuccess: {
            self.obsCurrentScene = name
            self.updateObsAudioInputs(sceneName: name)
        }, onError: { message in
            self.makeErrorToast(title: String(localized: "Failed to set OBS scene to \(name)"),
                                subTitle: message)
        })
    }

    func updateObsStatus() {
        guard isObsConnected() else {
            obsAudioVolumeLatest = noValue
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
            } else if obsCurrentScene != stream.obsBrbScene {
                return true
            }
        }
        if stream.obsBrbSceneVideoSourceBroken, let scene = getSelectedScene() {
            switch scene.cameraPosition {
            case .srtla:
                if let srtlaStream = getSrtlaStream(id: scene.srtlaCameraId) {
                    if srtlaServer?.isStreamConnected(streamId: srtlaStream.streamId) == false {
                        streamBecameBrokenTime = now
                        return true
                    }
                }
            case .rtmp:
                if let rtmpStream = getRtmpStream(id: scene.rtmpCameraId) {
                    if rtmpServer?.isStreamConnected(streamKey: rtmpStream.streamKey) == false {
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
        guard isLive, !stream.obsBrbScene.isEmpty, !obsCurrentScene.isEmpty, isObsConnected() else {
            return
        }
        if isStreamLikelyBroken(now: now) {
            if obsCurrentScene != stream.obsBrbScene {
                if !stream.obsMainScene.isEmpty {
                    obsSceneBeforeSwitchToBrbScene = stream.obsMainScene
                } else {
                    obsSceneBeforeSwitchToBrbScene = obsCurrentScene
                }
                makeStreamLikelyBrokenToast(scene: stream.obsBrbScene)
                setObsScene(name: stream.obsBrbScene)
            }
        } else if let obsSceneBeforeSwitchToBrbScene {
            if obsCurrentScene == stream.obsBrbScene {
                makeStreamLikelyWorkingToast(scene: obsSceneBeforeSwitchToBrbScene)
                setObsScene(name: obsSceneBeforeSwitchToBrbScene)
            } else if obsCurrentScene == obsSceneBeforeSwitchToBrbScene {
                self.obsSceneBeforeSwitchToBrbScene = nil
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

    func setObsRemoteControlEnabled(enabled: Bool) {
        stream.obsWebSocketEnabled = enabled
        if stream.enabled {
            obsWebSocketEnabledUpdated()
        }
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
        obsFixOngoing = true
        obsWebSocket.setInputSettings(inputName: stream.obsSourceName,
                                      onSuccess: {
                                          self.obsFixOngoing = false
                                      }, onError: { message in
                                          self.obsFixOngoing = false
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
        obsAudioVolumeLatest = noValue
        obsWebSocket?.startAudioVolume()
    }

    func stopObsAudioVolume() {
        obsWebSocket?.stopAudioVolume()
    }

    func updateObsAudioVolume() {
        if obsAudioVolumeLatest != obsAudioVolume {
            obsAudioVolume = obsAudioVolumeLatest
        }
    }

    func isShowingStatusObs() -> Bool {
        return database.show.obsStatus! && isObsRemoteControlConfigured()
    }

    func statusObsText() -> String {
        if !isObsRemoteControlConfigured() {
            return String(localized: "Not configured")
        } else if isObsConnected() {
            if obsStreaming && obsRecording {
                return "\(obsCurrentScene) (Streaming, Recording)"
            } else if obsStreaming {
                return "\(obsCurrentScene) (Streaming)"
            } else if obsRecording {
                return "\(obsCurrentScene) (Recording)"
            } else {
                return obsCurrentScene
            }
        } else {
            return obsConnectionErrorMessage()
        }
    }

    func isObsRemoteControlConfigured() -> Bool {
        return stream.obsWebSocketEnabled && stream.obsWebSocketUrl != "" && stream.obsWebSocketPassword != ""
    }
}

extension Model: ObsWebsocketDelegate {
    func obsWebsocketConnected() {
        updateObsStatus()
    }

    func obsWebsocketSceneChanged(sceneName: String) {
        obsCurrentScenePicker = sceneName
        obsCurrentScene = sceneName
        updateObsAudioInputs(sceneName: sceneName)
    }

    func obsWebsocketInputMuteStateChangedEvent(inputName: String, muted: Bool) {
        obsSceneInputs = obsSceneInputs.map { input in
            var input = input
            if input.name == inputName {
                input.muted = muted
            }
            return input
        }
    }

    func obsWebsocketStreamStatusChanged(active: Bool, state: ObsOutputState?) {
        obsStreaming = active
        if let state {
            obsStreamingState = state
        } else if active {
            obsStreamingState = .started
        } else {
            obsStreamingState = .stopped
        }
    }

    func obsWebsocketRecordStatusChanged(active: Bool, state: ObsOutputState?) {
        obsRecording = active
        if let state {
            obsRecordingState = state
        } else if active {
            obsRecordingState = .started
        } else {
            obsRecordingState = .stopped
        }
    }

    func obsWebsocketAudioVolume(volumes: [ObsAudioInputVolume]) {
        guard let volume = volumes.first(where: { volume in
            volume.name == self.stream.obsSourceName
        }) else {
            obsAudioVolumeLatest =
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
        obsAudioVolumeLatest = values.joined(separator: ", ")
    }
}
