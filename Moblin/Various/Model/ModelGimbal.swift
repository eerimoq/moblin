import Foundation

extension Model {
    func setGimbalTracking(on: Bool) {
        database.gimbal.tracking = on
        if #available(iOS 18.0, *) {
            Gimbal.shared?.setTracking(on: on)
        }
        setQuickButton(type: .gimbalTracking, isOn: on)
        updateQuickButtonStates()
    }

    func toggleGimbalTracking() {
        setGimbalTracking(on: !database.gimbal.tracking)
    }

    func saveGimbalPreset(id: UUID?) {
        guard #available(iOS 18.0, *) else {
            return
        }
        Task { @MainActor in
            do {
                guard let angles = try await Gimbal.shared?.getCurrentOrientation() else {
                    return
                }
                if let id {
                    if let preset = database.gimbal.presets.first(where: { $0.id == id }) {
                        preset.x = Float(angles.x)
                        preset.y = Float(angles.y)
                        preset.zoomX = zoom.x
                    }
                } else {
                    let preset = SettingsGimbalPreset()
                    preset.name = makeUniqueName(name: SettingsGimbalPreset.baseName,
                                                 existingNames: database.gimbal.presets)
                    preset.x = Float(angles.x)
                    preset.y = Float(angles.y)
                    preset.zoomX = zoom.x
                    database.gimbal.presets.append(preset)
                }
            } catch {
                makeErrorToast(
                    title: String(localized: "Failed to get gimbal orientation"),
                    subTitle: error.localizedDescription
                )
            }
        }
    }

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
