import GameController
import Spatial

private let gimbalAngularVelocity: Double = 0.3
private let thumbStickDeadZone: Float = 0.1

extension Model {
    func handleControllerFunction(function: SettingsControllerFunction,
                                  sceneId: UUID?,
                                  widgetId: UUID?,
                                  gimbalPresetId: UUID?,
                                  gimbalMotion: SettingsGimbalMotion,
                                  pressed: Bool)
    {
        switch function {
        case .unused:
            break
        case .record:
            if !pressed {
                toggleRecording()
                updateQuickButtonStates()
            }
        case .stream:
            if !pressed {
                toggleStream()
                updateQuickButtonStates()
            }
        case .zoomIn:
            handleGameControllerButtonZoom(pressed: pressed, x: .infinity)
        case .zoomOut:
            handleGameControllerButtonZoom(pressed: pressed, x: 0)
        case .gimbalUp:
            handleGameControllerButtonGimbal(
                pressed: pressed,
                velocity: .init(x: gimbalAngularVelocity, y: 0, z: 0)
            )
        case .gimbalDown:
            handleGameControllerButtonGimbal(
                pressed: pressed,
                velocity: .init(x: -gimbalAngularVelocity, y: 0, z: 0)
            )
        case .gimbalLeft:
            handleGameControllerButtonGimbal(
                pressed: pressed,
                velocity: .init(x: 0, y: gimbalAngularVelocity, z: 0)
            )
        case .gimbalRight:
            handleGameControllerButtonGimbal(
                pressed: pressed,
                velocity: .init(x: 0, y: -gimbalAngularVelocity, z: 0)
            )
        case .gimbalPreset:
            if !pressed {
                if let gimbalPresetId {
                    moveToGimbalPreset(id: gimbalPresetId)
                }
            }
        case .gimbalAnimate:
            if !pressed {
                if #available(iOS 18.0, *) {
                    Gimbal.shared?.animate(motion: gimbalMotion.toSystem())
                }
            }
        case .torch:
            if !pressed {
                toggleTorch()
                toggleQuickButton(type: .torch)
                updateQuickButtonStates()
            }
        case .mute:
            if !pressed {
                toggleMute()
                toggleQuickButton(type: .mute)
                updateQuickButtonStates()
            }
        case .blackScreen:
            if !pressed {
                toggleStealthMode()
                updateQuickButtonStates()
            }
        case .scene:
            if let sceneId, !pressed {
                selectScene(id: sceneId)
            }
        case .switchScene:
            if !pressed {
                switchToNextSceneRoundRobin()
            }
        case .widget:
            if let widgetId, !pressed {
                toggleWidgetOnOff(id: widgetId)
            }
        case .instantReplay:
            if !pressed {
                instantReplay()
            }
        case .stopReplay:
            if !pressed {
                replay.isPlaying = false
                replayCancel()
            }
        case .snapshot:
            if !pressed {
                takeSnapshot()
            }
        case .pauseTts:
            if !pressed {
                toggleTextToSpeechPaused()
            }
        case .pixellate:
            if !pressed {
                togglePixellateQuickButton()
            }
        case .movie:
            if !pressed {
                toggleFilterQuickButton(type: .movie)
            }
        case .grayScale:
            if !pressed {
                toggleFilterQuickButton(type: .grayScale)
            }
        case .sepia:
            if !pressed {
                toggleFilterQuickButton(type: .sepia)
            }
        case .triple:
            if !pressed {
                toggleFilterQuickButton(type: .triple)
            }
        case .twin:
            if !pressed {
                toggleFilterQuickButton(type: .twin)
            }
        case .cameraMan:
            if !pressed {
                toggleCameraManQuickButton()
            }
        case .fourThree:
            if !pressed {
                toggleFilterQuickButton(type: .fourThree)
            }
        case .pinch:
            if !pressed {
                togglePinchQuickButton()
            }
        case .whirlpool:
            if !pressed {
                toggleWhirlpoolQuickButton()
            }
        case .poll:
            if !pressed {
                togglePollQuickButton()
            }
        case .blurFaces:
            if !pressed {
                toggleBlurFaces()
            }
        case .privacy:
            if !pressed {
                togglePrivacy()
            }
        case .beauty:
            if !pressed {
                toggleBeautyQuickButton()
            }
        }
    }

    func isGameControllerConnected() -> Bool {
        return numberOfGameControllers() > 0
    }

    private func handleGameControllerButtonZoom(pressed: Bool, x: Float) {
        if pressed {
            setZoomX(x: x, rate: database.zoom.speed)
        } else {
            if let x = stopCameraZoom() {
                setZoomXWhenInRange(x: x)
            }
        }
    }

    private func handleGameControllerButtonGimbal(pressed: Bool, velocity: Vector3D) {
        if #available(iOS 18.0, *) {
            if pressed {
                Gimbal.shared?.setMovement(velocity: velocity)
            } else {
                Gimbal.shared?.cancelMovement()
            }
        }
    }

    private func handleGameControllerThumbStick(
        function: SettingsControllerThumbStickFunction,
        xValue: Float,
        yValue: Float
    ) {
        guard function != .unused else {
            return
        }
        switch function {
        case .unused:
            break
        case .gimbalPanTilt:
            if #available(iOS 18.0, *) {
                let x = abs(xValue) > thumbStickDeadZone ? xValue : 0
                let y = abs(yValue) > thumbStickDeadZone ? yValue : 0
                if x == 0, y == 0 {
                    Gimbal.shared?.cancelMovement()
                } else {
                    Gimbal.shared?.setMovement(velocity: .init(
                        x: Double(y) * gimbalAngularVelocity,
                        y: Double(-x) * gimbalAngularVelocity,
                        z: 0
                    ))
                }
            }
        }
    }

    private func handleGameControllerButton(
        _ gameController: GCController,
        _ button: GCControllerButtonInput,
        _: Float,
        _ pressed: Bool
    ) {
        guard let gameControllerIndex = gameControllers.firstIndex(of: gameController) else {
            return
        }
        guard gameControllerIndex < database.gameControllers.count else {
            return
        }
        guard let name = button.sfSymbolsName else {
            return
        }
        let button = database.gameControllers[gameControllerIndex].buttons.first(where: { button in
            button.name == name
        })
        guard let button else {
            return
        }
        handleControllerFunction(function: button.function,
                                 sceneId: button.sceneId,
                                 widgetId: button.widgetId,
                                 gimbalPresetId: button.gimbalPresetId,
                                 gimbalMotion: button.gimbalMotion,
                                 pressed: pressed)
    }

    private func numberOfGameControllers() -> Int {
        return gameControllers.filter { $0 != nil }.count
    }

    private func updateGameControllers() {
        statusTopRight.gameControllersTotal = String(numberOfGameControllers())
    }

    private func gameControllerNumber(gameController: GCController) -> Int? {
        if let gameControllerIndex = gameControllers.firstIndex(of: gameController) {
            return gameControllerIndex + 1
        }
        return nil
    }

    @objc func handleGameControllerDidConnect(_ notification: Notification) {
        guard let gameController = notification.object as? GCController else {
            return
        }
        guard let gamepad = gameController.extendedGamepad else {
            return
        }
        gamepad.dpad.left.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.up.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonA.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonX.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonY.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.buttonMenu.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftShoulder.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftTrigger.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.rightTrigger.pressedChangedHandler = { button, value, pressed in
            self.handleGameControllerButton(gameController, button, value, pressed)
        }
        gamepad.leftThumbstick.valueChangedHandler = { _, xValue, yValue in
            guard let index = self.gameControllers.firstIndex(of: gameController),
                  index < self.database.gameControllers.count
            else {
                return
            }
            let function = self.database.gameControllers[index].leftThumbStickFunction
            self.handleGameControllerThumbStick(function: function, xValue: xValue, yValue: yValue)
        }
        gamepad.rightThumbstick.valueChangedHandler = { _, xValue, yValue in
            guard let index = self.gameControllers.firstIndex(of: gameController),
                  index < self.database.gameControllers.count
            else {
                return
            }
            let function = self.database.gameControllers[index].rightThumbStickFunction
            self.handleGameControllerThumbStick(function: function, xValue: xValue, yValue: yValue)
        }
        if let index = gameControllers.firstIndex(of: nil) {
            gameControllers[index] = gameController
        } else {
            gameControllers.append(gameController)
        }
        if let number = gameControllerNumber(gameController: gameController) {
            makeToast(title: String(localized: "Game controller \(number) connected"))
        }
        updateGameControllers()
    }

    @objc func handleGameControllerDidDisconnect(notification: Notification) {
        guard let gameController = notification.object as? GCController else {
            return
        }
        if let number = gameControllerNumber(gameController: gameController) {
            makeToast(title: String(localized: "Game controller \(number) disconnected"))
        }
        if let index = gameControllers.firstIndex(of: gameController) {
            gameControllers[index] = nil
        }
        updateGameControllers()
    }

    func isShowingStatusGameController() -> Bool {
        return database.show.gameController && isGameControllerConnected()
    }
}
