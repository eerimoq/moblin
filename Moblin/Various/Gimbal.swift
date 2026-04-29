import DockKit
import Foundation
import Spatial

@available(iOS 18.0, *)
class Gimbal {
    private let model: Model
    private var task: Task<Void, Never>?
    private var accessoryTask: Task<Void, Never>?
    private var accessory: DockAccessory?
    private var motionTask: Task<Void, Never>?
    private var shutterCount: Int = 0
    private var currentAngularPositions: Vector3D?
    static var shared: Gimbal?

    init(model: Model) {
        self.model = model
        task = Task { @MainActor [weak self] in
            do {
                for await stateChange in try DockAccessoryManager.shared.accessoryStateChanges {
                    try self?.handleStateChange(stateChange: stateChange)
                }
            } catch {
                logger.info("gimbal: State changes error: \(error)")
            }
        }
    }

    func isConnected() -> Bool {
        return accessory != nil
    }

    func setOrientation(angles: Vector3D) async {
        _ = try? await accessory?.setOrientation(angles)
    }

    func animate(motion: DockAccessory.Animation) {
        Task { @MainActor [weak self] in
            _ = try await self?.accessory?.animate(motion: motion)
        }
    }

    func setMovement(velocity: Vector3D) {
        Task { @MainActor [weak self] in
            _ = try await self?.accessory?.setAngularVelocity(velocity)
        }
    }

    func cancelMovement() {
        setMovement(velocity: .init(x: 0, y: 0, z: 0))
    }

    func getCurrentOrientation() -> Vector3D? {
        return currentAngularPositions
    }

    private func handleStateChange(stateChange: DockAccessory.StateChange) throws {
        logger.info("gimbal: State changed to \(stateChange.state)")
        switch stateChange.state {
        case .docked:
            if let accessory = stateChange.accessory {
                startAccessoryEventsHandler(accessory: accessory)
            }
        case .undocked:
            stopAccessoryEventsHandler()
        default:
            break
        }
    }

    private func startAccessoryEventsHandler(accessory: DockAccessory) {
        stopAccessoryEventsHandler()
        self.accessory = accessory
        shutterCount = 0
        accessoryTask = Task { @MainActor [weak self] in
            do {
                try await DockAccessoryManager.shared.setSystemTrackingEnabled(false)
                for await event in try accessory.accessoryEvents {
                    self?.handleAccessoryEvent(event)
                }
            } catch {
                logger.info("gimbal: Accessory events error: \(error)")
            }
        }
        motionTask = Task { @MainActor [weak self] in
            do {
                for await state in try accessory.motionStates {
                    logger.info("gimbal: state \(state.angularPositions)")
                    self?.currentAngularPositions = state.angularPositions
                }
            } catch {
                logger.info("gimbal: Motion states error: \(error)")
            }
        }
    }

    private func stopAccessoryEventsHandler() {
        accessoryTask?.cancel()
        accessoryTask = nil
        motionTask?.cancel()
        motionTask = nil
        accessory = nil
        currentAngularPositions = nil
    }

    private func handleAccessoryEvent(_ event: DockAccessory.AccessoryEvent) {
        switch event {
        case .cameraShutter:
            handleAccessoryEventCameraShutter()
        case .cameraFlip:
            handleAccessoryEventCameraFlip()
        case let .cameraZoom(factor):
            handleAccessoryEventCameraZoom(factor: factor)
        default:
            break
        }
    }

    private func handleAccessoryEventCameraShutter() {
        shutterCount += 1
        guard (shutterCount % 2) == 0 else {
            return
        }
        let gimbal = model.database.gimbal
        model.handleControllerFunction(function: gimbal.functionShutter,
                                       sceneId: gimbal.shutterSceneId,
                                       widgetId: gimbal.shutterWidgetId,
                                       gimbalPresetId: gimbal.shutterGimbalPresetId,
                                       gimbalMotion: gimbal.motion,
                                       pressed: false)
    }

    private func handleAccessoryEventCameraFlip() {
        let gimbal = model.database.gimbal
        model.handleControllerFunction(function: gimbal.functionFlip,
                                       sceneId: gimbal.flipSceneId,
                                       widgetId: gimbal.flipWidgetId,
                                       gimbalPresetId: gimbal.flipGimbalPresetId,
                                       gimbalMotion: gimbal.motion,
                                       pressed: false)
    }

    private func handleAccessoryEventCameraZoom(factor: Double) {
        let gimbal = model.database.gimbal
        var zoomIn = factor <= 0
        if !gimbal.naturalZoom {
            zoomIn = !zoomIn
        }
        let zoomSpeed = 1 + gimbal.zoomSpeed / 1000
        let rate = 1 + 2 * Float(pow(Double(gimbal.zoomSpeed) / 50.0, 1.3))
        if zoomIn {
            model.setZoomX(x: model.zoom.x * zoomSpeed, rate: rate)
        } else {
            model.setZoomX(x: model.zoom.x / zoomSpeed, rate: rate)
        }
    }
}
