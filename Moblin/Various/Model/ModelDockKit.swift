import DockKit
import Foundation

@available(iOS 17.4, *)
extension Model {
    func setupDockKit() {
        dockKitTask = Task { @MainActor [weak self] in
            do {
                for await stateChange in try DockAccessoryManager.shared.accessoryStateChanges {
                    try self?.handleStateChange(stateChange: stateChange)
                }
            } catch {
                logger.info("dockkit: State changes error: \(error)")
            }
        }
    }

    private func handleStateChange(stateChange: DockAccessory.StateChange) throws {
        switch stateChange.state {
        case .docked:
            if let accessory = stateChange.accessory {
                startDockKitAccessoryEventsHandler(accessory: accessory)
            }
        case .undocked:
            stopDockKitAccessoryEventsHandler()
        default:
            break
        }
    }

    private func startDockKitAccessoryEventsHandler(accessory: DockAccessory) {
        stopDockKitAccessoryEventsHandler()
        dockKitAccessoryTask = Task { @MainActor [weak self] in
            do {
                for await event in try accessory.accessoryEvents {
                    self?.handleDockKitAccessoryEvent(event)
                }
            } catch {
                logger.info("dockkit: Accessory events error: \(error)")
            }
        }
    }

    private func stopDockKitAccessoryEventsHandler() {
        dockKitAccessoryTask?.cancel()
        dockKitAccessoryTask = nil
    }

    private func handleDockKitAccessoryEvent(_ event: DockAccessory.AccessoryEvent) {
        switch event {
        case .cameraShutter:
            handleDockKitAccessoryEventCameraShutter()
        case .cameraFlip:
            handleDockKitAccessoryEventCameraFlip()
        case let .cameraZoom(factor):
            handleDockKitAccessoryEventCameraZoom(factor: factor)
        default:
            break
        }
    }

    private func handleDockKitAccessoryEventCameraShutter() {
        let now = ContinuousClock.now
        if let dockKitLastShutterTime,
           dockKitLastShutterTime.duration(to: now) < .milliseconds(500)
        {
            return
        }
        dockKitLastShutterTime = now
        let gimbal = database.gimbal
        handleControllerFunction(function: gimbal.functionShutter,
                                 sceneId: gimbal.shutterSceneId,
                                 widgetId: gimbal.shutterWidgetId,
                                 pressed: false)
    }

    private func handleDockKitAccessoryEventCameraFlip() {
        let gimbal = database.gimbal
        handleControllerFunction(function: gimbal.functionFlip,
                                 sceneId: gimbal.flipSceneId,
                                 widgetId: gimbal.flipWidgetId,
                                 pressed: false)
    }

    private func handleDockKitAccessoryEventCameraZoom(factor: Double) {
        let gimbal = database.gimbal
        if gimbal.zoomSpeedEnabled {
            if factor > 0 {
                setZoomX(x: zoom.x * database.gimbal.zoomSpeed)
            } else {
                setZoomX(x: zoom.x / database.gimbal.zoomSpeed)
            }
        } else {
            setZoomX(x: zoom.x * Float(factor))
        }
    }
}
