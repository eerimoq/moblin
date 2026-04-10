import DockKit
import Foundation

@available(iOS 17.4, *)
extension Model {
    func setupDockKit() {
        dockKitTask = Task { @MainActor [weak self] in
            do {
                for await stateChange in try DockAccessoryManager.shared.accessoryStateChanges {
                    guard let self else { return }
                    switch stateChange.state {
                    case .docked:
                        if let accessory = stateChange.accessory {
                            self.startDockKitEvents(accessory: accessory)
                        }
                    case .undocked:
                        self.dockKitAccessoryTask?.cancel()
                        self.dockKitAccessoryTask = nil
                    @unknown default:
                        break
                    }
                }
            } catch {
                logger.info("dockkit: State changes error: \(error)")
            }
        }
    }

    private func startDockKitEvents(accessory: DockAccessory) {
        dockKitAccessoryTask?.cancel()
        dockKitAccessoryTask = Task { @MainActor [weak self] in
            do {
                for await event in try accessory.accessoryEvents {
                    self?.handleDockKitEvent(event)
                }
            } catch {
                logger.info("dockkit: Accessory events error: \(error)")
            }
        }
    }

    private func handleDockKitEvent(_ event: DockAccessory.AccessoryEvent) {
        switch event {
        case .cameraShutter:
            let now = ContinuousClock.now
            guard dockKitLastShutterTime.map({ now - $0 > .milliseconds(500) }) ?? true else {
                break
            }
            dockKitLastShutterTime = now
            toggleRecording()
            updateQuickButtonStates()
        case .cameraFlip:
            switchToNextSceneRoundRobin()
        case let .cameraZoom(factor):
            let step = Float(database.debug.dockKitZoomStep)
            let newX = zoom.x * (factor > 0 ? step : 1.0 / step)
            setZoomX(x: newX)
            let presets = cameraPosition == .back ? zoom.backZoomPresets : zoom.frontZoomPresets
            if let nearest = presets.min(by: { abs($0.x - newX) < abs($1.x - newX) }),
               abs(nearest.x - newX) / nearest.x < 0.05
            {
                switch cameraPosition {
                case .back:
                    zoom.backPresetId = nearest.id
                case .front:
                    zoom.frontPresetId = nearest.id
                default:
                    break
                }
            }
        default:
            break
        }
    }
}
