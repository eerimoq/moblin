import AVFoundation
import Foundation

private let noBackZoomPresetId = UUID()
private let noFrontZoomPresetId = UUID()

extension Model {
    func setZoomPreset(id: UUID) {
        switch cameraPosition {
        case .back:
            zoom.backZoomPresetId = id
        case .front:
            zoom.frontZoomPresetId = id
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
        zoom.zoomX = x
        remoteControlStreamer?.stateChanged(state: RemoteControlState(zoom: x))
        if isWatchLocal() {
            sendZoomToWatch(x: x)
        }
        if setPinch {
            zoomXPinch = zoom.zoomX
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
            zoom.backZoomPresetId = noBackZoomPresetId
        case .front:
            zoom.frontZoomPresetId = noFrontZoomPresetId
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
            level.id == zoom.backZoomPresetId
        }) {
            zoom.backZoomPresetId = database.zoom.back[0].id
        }
        sceneUpdated(updateRemoteScene: false)
    }

    func frontZoomUpdated() {
        if !database.zoom.front.contains(where: { level in
            level.id == zoom.frontZoomPresetId
        }) {
            zoom.frontZoomPresetId = database.zoom.front[0].id
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
            zoom.backZoomPresetId = preset.id
        }
    }

    private func updateFrontZoomPresetId() {
        for preset in database.zoom.front where preset.x == frontZoomX {
            zoom.frontZoomPresetId = preset.id
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

    private func factorToX(position: AVCaptureDevice.Position, factor: Float) -> Float {
        if position == .back && hasUltraWideBackCamera() {
            return factor / 2
        }
        return factor
    }

    func getMinMaxZoomX(position: AVCaptureDevice.Position) -> (Float, Float) {
        var minX: Float
        var maxX: Float
        if let device = preferredCamera(position: position) {
            minX = factorToX(
                position: position,
                factor: Float(device.minAvailableVideoZoomFactor)
            )
            maxX = factorToX(
                position: position,
                factor: Float(device.maxAvailableVideoZoomFactor)
            )
        } else {
            minX = 1.0
            maxX = 1.0
        }
        return (minX, maxX)
    }

    func isShowingStatusZoom() -> Bool {
        return database.show.zoom && hasZoom
    }

    func statusZoomText() -> String {
        return String(format: "%.1f", zoom.zoomX)
    }

    private func showPreset(preset: SettingsZoomPreset) -> Bool {
        let x = preset.x!
        return x >= cameraZoomXMinimum && x <= cameraZoomXMaximum
    }

    func backZoomPresets() -> [SettingsZoomPreset] {
        return database.zoom.back.filter { showPreset(preset: $0) }
    }

    func frontZoomPresets() -> [SettingsZoomPreset] {
        return database.zoom.front.filter { showPreset(preset: $0) }
    }

    func setCameraZoomX(x: Float, rate: Float? = nil) -> Float? {
        return cameraZoomLevelToX(media.setCameraZoomLevel(
            device: cameraDevice,
            level: x / cameraZoomLevelToXScale,
            rate: rate
        ))
    }

    func stopCameraZoom() -> Float? {
        return cameraZoomLevelToX(media.stopCameraZoomLevel(device: cameraDevice))
    }

    private func cameraZoomLevelToX(_ level: Float?) -> Float? {
        if let level {
            return level * cameraZoomLevelToXScale
        }
        return nil
    }
}
