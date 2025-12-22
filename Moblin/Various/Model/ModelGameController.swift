import GameController

extension Model {
    private func handleGameControllerButtonZoom(pressed: Bool, x: Float) {
        if pressed {
            setZoomX(x: x, rate: database.zoom.speed)
        } else {
            if let x = stopCameraZoom() {
                setZoomXWhenInRange(x: x)
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
                                 pressed: pressed)
    }

    func handleControllerFunction(function: SettingsControllerFunction,
                                  sceneId: UUID,
                                  widgetId: UUID,
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
            handleGameControllerButtonZoom(pressed: pressed, x: Float.infinity)
        case .zoomOut:
            handleGameControllerButtonZoom(pressed: pressed, x: 0)
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
            if !pressed {
                selectScene(id: sceneId)
            }
        case .widget:
            if !pressed {
                toggleWidgetOnOff(id: widgetId)
            }
        case .instantReplay:
            if !pressed {
                instantReplay()
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
        }
    }

    private func numberOfGameControllers() -> Int {
        return gameControllers.filter { $0 != nil }.count
    }

    func isGameControllerConnected() -> Bool {
        return numberOfGameControllers() > 0
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
