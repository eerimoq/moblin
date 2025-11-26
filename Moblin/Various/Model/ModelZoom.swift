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
        if let preset = findZoomPreset(id: id) {
            switch cameraPosition {
            case .back:
                setBackZoomPreset(presetId: id)
            case .front:
                setFrontZoomPreset(presetId: id)
            default:
                break
            }
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
            setBackZoomPreset(presetId: noBackZoomPresetId)
        case .front:
            setFrontZoomPreset(presetId: noFrontZoomPresetId)
        default:
            break
        }
    }

    private func setBackZoomPreset(presetId: UUID) {
        zoom.backPresetId = presetId
        if cameraPosition == .back {
            remoteControlStreamer?.stateChanged(state: RemoteControlState(zoomPreset: presetId))
            if isWatchLocal() {
                sendZoomPresetToWatch()
            }
        }
    }

    private func setFrontZoomPreset(presetId: UUID) {
        zoom.frontPresetId = presetId
        if cameraPosition == .front {
            remoteControlStreamer?.stateChanged(state: RemoteControlState(zoomPreset: presetId))
            if isWatchLocal() {
                sendZoomPresetToWatch()
            }
        }
    }

    private func findZoomPreset(id: UUID) -> SettingsZoomPreset? {
        switch cameraPosition {
        case .back:
            return database.zoom.back.first { $0.id == id }
        case .front:
            return database.zoom.front.first { $0.id == id }
        default:
            return nil
        }
    }

    func backZoomPresetSettingsUpdated() {
        if !database.zoom.back.contains(where: { $0.id == zoom.backPresetId }) {
            setBackZoomPreset(presetId: noBackZoomPresetId)
        }
        updateBackZoomPresets()
    }

    func frontZoomPresetSettingUpdated() {
        if !database.zoom.front.contains(where: { $0.id == zoom.frontPresetId }) {
            setFrontZoomPreset(presetId: noFrontZoomPresetId)
        }
        updateFrontZoomPresets()
    }

    func updateFrontZoomPresets() {
        zoom.frontZoomPresets = database.zoom.front.filter { showPreset(preset: $0) }
        if cameraPosition == .front {
            let presets = zoom.frontZoomPresets.map { RemoteControlZoomPreset(id: $0.id, name: $0.name) }
            remoteControlStreamer?
                .stateChanged(state: RemoteControlState(zoomPresets: presets))
            if isWatchLocal() {
                sendZoomPresetsToWatch()
            }
        }
    }

    func updateBackZoomPresets() {
        zoom.backZoomPresets = database.zoom.back.filter { showPreset(preset: $0) }
        if cameraPosition == .back {
            let presets = zoom.backZoomPresets.map { RemoteControlZoomPreset(id: $0.id, name: $0.name) }
            remoteControlStreamer?.stateChanged(state: RemoteControlState(zoomPresets: presets))
            if isWatchLocal() {
                sendZoomPresetsToWatch()
            }
        }
    }

    func lowEnergyCameraUpdateBackZoom(force: Bool) {
        if force {
            updateBackZoomSwitchTo()
        }
    }

    private func updateBackZoomPresetId() {
        if let preset = database.zoom.back.first(where: { $0.x == zoom.backX }) {
            setBackZoomPreset(presetId: preset.id)
        }
    }

    private func updateFrontZoomPresetId() {
        if let preset = database.zoom.front.first(where: { $0.x == zoom.frontX }) {
            setFrontZoomPreset(presetId: preset.id)
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
