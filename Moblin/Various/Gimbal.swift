import DockKit
import Foundation
import Spatial

@available(iOS 18.0, *)
@MainActor
class Gimbal {
    private let model: Model
    private var task: Task<Void, Never>?
    private var accessoryTask: Task<Void, Never>?
    private var accessory: DockAccessory?
    private var shutterCount: Int = 0
    private var tracking: Bool = true
    static var shared: Gimbal?

    init(model: Model) {
        self.model = model
        task = Task { [weak self] in
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
        accessory != nil
    }

    func setTracking(on: Bool) {
        Task { @MainActor in
            try? await DockAccessoryManager.shared.setSystemTrackingEnabled(on)
            tracking = on
        }
    }

    func setOrientation(angles: Vector3D) async {
        guard !tracking else {
            return
        }
        _ = try? await accessory?.setOrientation(angles)
    }

    func animate(motion: DockAccessory.Animation) {
        Task { @MainActor [weak self] in
            guard let self, !tracking else {
                return
            }
            _ = try await accessory?.animate(motion: motion)
        }
    }

    func setMovement(velocity: Vector3D) {
        Task { @MainActor [weak self] in
            guard let self, !tracking else {
                return
            }
            _ = try await accessory?.setAngularVelocity(velocity)
        }
    }

    func cancelMovement() {
        setMovement(velocity: .init(x: 0, y: 0, z: 0))
    }

    func getCurrentOrientation() async throws -> Vector3D? {
        guard !tracking else {
            return nil
        }
        var iterator = try accessory?.motionStates.makeAsyncIterator()
        return await iterator?.next()?.angularPositions
    }

    private func handleStateChange(stateChange: DockAccessory.StateChange) throws {
        logger.info("""
        gimbal: State changed to \(stateChange.state) with tracking button \
        \(stateChange.trackingButtonEnabled)
        """)
        switch stateChange.state {
        case .docked:
            if let accessory = stateChange.accessory, accessory != self.accessory {
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
        accessoryTask = Task { [weak self] in
            do {
                for await event in try accessory.accessoryEvents {
                    self?.handleAccessoryEvent(event)
                }
            } catch {
                logger.info("gimbal: Accessory events error: \(error)")
            }
        }
    }

    private func stopAccessoryEventsHandler() {
        accessoryTask?.cancel()
        accessoryTask = nil
        accessory = nil
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
        model.handleControllerFunction(buttonId: "g:shutter",
                                       function: gimbal.functionShutter,
                                       functionData: gimbal.functionDataShutter,
                                       pressed: false)
    }

    private func handleAccessoryEventCameraFlip() {
        let gimbal = model.database.gimbal
        model.handleControllerFunction(buttonId: "g:flip",
                                       function: gimbal.functionFlip,
                                       functionData: gimbal.functionDataFlip,
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
