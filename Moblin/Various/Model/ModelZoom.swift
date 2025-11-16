import AVFoundation
import Foundation

private let noBackZoomPresetId = UUID()
private let noFrontZoomPresetId = UUID()

class Zoom: ObservableObject {
    var xPinch: Float = 1.0
    var backX: Float = 0.5
    var frontX: Float = 0.5
    @Published var backPresetId = UUID()
    @Published var frontPresetId = UUID()
    @Published var x: Float = 1.0
    @Published var hasZoom = true
    @Published var backZoomPresets: [SettingsZoomPreset] = []
    @Published var frontZoomPresets: [SettingsZoomPreset] = []

    func statusText() -> String {
        return String(format: "%.1f", x)
    }
}

extension Model {
    func setZoomPreset(id: UUID) {
        switch cameraPosition {
        case .back:
            zoom.backPresetId = id
        case .front:
            zoom.frontPresetId = id
        default:
            break
        }
        if let preset = findZoomPreset(id: id) {
            if setCameraZoomX(x: preset.x, rate: database.zoom.speed) != nil {
                setZoomXWhenInRange(x: preset.x)
                switch getSelectedScene()?.videoSource.cameraPosition {
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
            zoom.backX = x
            updateBackZoomPresetId()
        case .front:
            zoom.frontX = x
            updateFrontZoomPresetId()
        default:
            break
        }
        zoom.x = x
        remoteControlStreamer?.stateChanged(state: RemoteControlState(zoom: x))
        if isWatchLocal() {
            sendZoomToWatch(x: x)
        }
        if setPinch {
            zoom.xPinch = zoom.x
        }
    }

    func changeZoomX(amount: Float, rate: Float? = nil) {
        guard zoom.hasZoom else {
            return
        }
        setZoomX(x: zoom.xPinch * amount, rate: rate, setPinch: false)
    }

    func commitZoomX(amount: Float, rate: Float? = nil) {
        guard zoom.hasZoom else {
            return
        }
        setZoomX(x: zoom.xPinch * amount, rate: rate)
    }

    private func clearZoomPresetId() {
        switch cameraPosition {
        case .back:
            zoom.backPresetId = noBackZoomPresetId
        case .front:
            zoom.frontPresetId = noFrontZoomPresetId
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
            level.id == zoom.backPresetId
        }) {
            zoom.backPresetId = database.zoom.back[0].id
        }
        updateBackZoomPresets()
        sceneUpdated(updateRemoteScene: false)
    }

    func frontZoomUpdated() {
        if !database.zoom.front.contains(where: { level in
            level.id == zoom.frontPresetId
        }) {
            zoom.frontPresetId = database.zoom.front[0].id
        }
        updateFrontZoomPresets()
        sceneUpdated(updateRemoteScene: false)
    }

    func lowEnergyCameraUpdateBackZoom(force: Bool) {
        if force {
            updateBackZoomSwitchTo()
        }
    }

    private func updateBackZoomPresetId() {
        for preset in database.zoom.back where preset.x == zoom.backX {
            zoom.backPresetId = preset.id
        }
    }

    private func updateFrontZoomPresetId() {
        for preset in database.zoom.front where preset.x == zoom.frontX {
            zoom.frontPresetId = preset.id
        }
    }

    func updateBackZoomSwitchTo() {
        if database.zoom.switchToBack.enabled {
            clearZoomPresetId()
            zoom.backX = database.zoom.switchToBack.x
            updateBackZoomPresetId()
        }
    }

    func updateFrontZoomSwitchTo() {
        if database.zoom.switchToFront.enabled {
            clearZoomPresetId()
            zoom.frontX = database.zoom.switchToFront.x
            updateFrontZoomPresetId()
        }
    }

    private func factorToX(position: AVCaptureDevice.Position, factor: Float) -> Float {
        if position == .back && hasUltraWideBackCamera {
            return factor / 2
        } else if position == .front && hasUltraWideFrontCamera {
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
        return database.show.zoom && zoom.hasZoom
    }

    private func showPreset(preset: SettingsZoomPreset) -> Bool {
        let x = preset.x
        return x >= cameraZoomXMinimum && x <= cameraZoomXMaximum
    }

    func updateBackZoomPresets() {
        zoom.backZoomPresets = database.zoom.back.filter { showPreset(preset: $0) }
    }

    func updateFrontZoomPresets() {
        zoom.frontZoomPresets = database.zoom.front.filter { showPreset(preset: $0) }
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
