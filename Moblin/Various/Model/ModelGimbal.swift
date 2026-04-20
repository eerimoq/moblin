import Foundation

extension Model {
    func moveToGimbalPreset(id: UUID) {
        moveToGimbalPresetQueue.append(id)
        processGimbalPresetQueue()
    }

    private func processGimbalPresetQueue() {
        guard !moveToGimbalPresetQueueRunning else {
            return
        }
        guard let id = moveToGimbalPresetQueue.popFirst() else {
            return
        }
        guard #available(iOS 18.0, *) else {
            return
        }
        guard let preset = database.gimbal.presets.first(where: { $0.id == id }) else {
            processGimbalPresetQueue()
            return
        }
        moveToGimbalPresetQueueRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setZoomX(x: preset.zoomX, rate: 5)
        }
        Task { @MainActor [weak self] in
            defer {
                self?.moveToGimbalPresetQueueRunning = false
                self?.processGimbalPresetQueue()
            }
            await Gimbal.shared?.setOrientation(angles: .init(x: preset.x, y: preset.y, z: 0))
        }
    }
}
