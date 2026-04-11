import DockKit
import Foundation

@available(iOS 17.4, *)
extension Model {
    func setupGimbal() {
        gimbalTask = Task { @MainActor [weak self] in
            do {
                for await stateChange in try DockAccessoryManager.shared.accessoryStateChanges {
                    try self?.handleStateChange(stateChange: stateChange)
                }
            } catch {
                logger.info("gimbal: State changes error: \(error)")
            }
        }
    }

    private func handleStateChange(stateChange: DockAccessory.StateChange) throws {
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
        gimbalShutterCount = 0
        gimbalAccessoryTask = Task { @MainActor [weak self] in
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
        gimbalAccessoryTask?.cancel()
        gimbalAccessoryTask = nil
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
        gimbalShutterCount += 1
        guard (gimbalShutterCount % 2) == 0 else {
            return
        }
        let gimbal = database.gimbal
        handleControllerFunction(function: gimbal.functionShutter,
                                 sceneId: gimbal.shutterSceneId,
                                 widgetId: gimbal.shutterWidgetId,
                                 pressed: false)
    }

    private func handleAccessoryEventCameraFlip() {
        let gimbal = database.gimbal
        handleControllerFunction(function: gimbal.functionFlip,
                                 sceneId: gimbal.flipSceneId,
                                 widgetId: gimbal.flipWidgetId,
                                 pressed: false)
    }

    private func handleAccessoryEventCameraZoom(factor: Double) {
        let gimbal = database.gimbal
        if factor > 0 {
            setZoomX(x: zoom.x * gimbal.zoomSpeed)
        } else {
            setZoomX(x: zoom.x / gimbal.zoomSpeed)
        }
    }
}
