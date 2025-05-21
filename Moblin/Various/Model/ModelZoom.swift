import Foundation

private let noBackZoomPresetId = UUID()
private let noFrontZoomPresetId = UUID()

extension Model {
    func setZoomPreset(id: UUID) {
        switch cameraPosition {
        case .back:
            backZoomPresetId = id
        case .front:
            frontZoomPresetId = id
        default:
            break
        }
        if let preset = findZoomPreset(id: id) {
            if setCameraZoomX(x: preset.x!, rate: database.zoom.speed!) != nil {
                setZoomXWhenInRange(x: preset.x!)
                switch getSelectedScene()?.cameraPosition {
                case .backTripleLowEnergy:
                    attachBackTripleLowEnergyCamera(force: false)
                case .backDualLowEnergy:
                    attachBackDualLowEnergyCamera(force: false)
                case .backWideDualLowEnergy:
                    attachBackWideDualLowEnergyCamera(force: false)
                default:
                    break
                }
            }
            if isWatchLocal() {
                sendZoomPresetToWatch()
            }
        } else {
            clearZoomPresetId()
        }
    }

    func setZoomX(x: Float, rate: Float? = nil, setPinch: Bool = true) {
        clearZoomPresetId()
        if let x = setCameraZoomX(x: x, rate: rate) {
            setZoomXWhenInRange(x: x, setPinch: setPinch)
        }
    }

    func setZoomXWhenInRange(x: Float, setPinch: Bool = true) {
        switch cameraPosition {
        case .back:
            backZoomX = x
            updateBackZoomPresetId()
        case .front:
            frontZoomX = x
            updateFrontZoomPresetId()
        default:
            break
        }
        zoomX = x
        remoteControlStreamer?.stateChanged(state: RemoteControlState(zoom: x))
        if isWatchLocal() {
            sendZoomToWatch(x: x)
        }
        if setPinch {
            zoomXPinch = zoomX
        }
    }

    func changeZoomX(amount: Float, rate: Float? = nil) {
        guard hasZoom else {
            return
        }
        setZoomX(x: zoomXPinch * amount, rate: rate, setPinch: false)
    }

    func commitZoomX(amount: Float, rate: Float? = nil) {
        guard hasZoom else {
            return
        }
        setZoomX(x: zoomXPinch * amount, rate: rate)
    }

    private func clearZoomPresetId() {
        switch cameraPosition {
        case .back:
            backZoomPresetId = noBackZoomPresetId
        case .front:
            frontZoomPresetId = noFrontZoomPresetId
        default:
            break
        }
        if isWatchLocal() {
            sendZoomPresetToWatch()
        }
    }

    private func findZoomPreset(id: UUID) -> SettingsZoomPreset? {
        switch cameraPosition {
        case .back:
            return database.zoom.back.first { preset in
                preset.id == id
            }
        case .front:
            return database.zoom.front.first { preset in
                preset.id == id
            }
        default:
            return nil
        }
    }

    func backZoomUpdated() {
        if !database.zoom.back.contains(where: { level in
            level.id == backZoomPresetId
        }) {
            backZoomPresetId = database.zoom.back[0].id
        }
        sceneUpdated(updateRemoteScene: false)
    }

    func frontZoomUpdated() {
        if !database.zoom.front.contains(where: { level in
            level.id == frontZoomPresetId
        }) {
            frontZoomPresetId = database.zoom.front[0].id
        }
        sceneUpdated(updateRemoteScene: false)
    }

    func lowEnergyCameraUpdateBackZoom(force: Bool) {
        if force {
            updateBackZoomSwitchTo()
        }
    }

    private func updateBackZoomPresetId() {
        for preset in database.zoom.back where preset.x == backZoomX {
            backZoomPresetId = preset.id
        }
    }

    private func updateFrontZoomPresetId() {
        for preset in database.zoom.front where preset.x == frontZoomX {
            frontZoomPresetId = preset.id
        }
    }

    func updateBackZoomSwitchTo() {
        if database.zoom.switchToBack.enabled {
            clearZoomPresetId()
            backZoomX = database.zoom.switchToBack.x!
            updateBackZoomPresetId()
        }
    }

    func updateFrontZoomSwitchTo() {
        if database.zoom.switchToFront.enabled {
            clearZoomPresetId()
            frontZoomX = database.zoom.switchToFront.x!
            updateFrontZoomPresetId()
        }
    }
}
