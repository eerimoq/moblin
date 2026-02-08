import Foundation

extension Model {
    func isWorkoutDeviceEnabled(device: SettingsWorkoutDevice) -> Bool {
        return device.enabled
    }

    func enableWorkoutDevice(device: SettingsWorkoutDevice) {
        if !workoutDevices.keys.contains(device.id) {
            let workoutDevice = WorkoutDevice()
            workoutDevice.delegate = self
            workoutDevices[device.id] = workoutDevice
        }
        workoutDevices[device.id]?.start(deviceId: device.bluetoothPeripheralId)
    }

    func disableWorkoutDevice(device: SettingsWorkoutDevice) {
        workoutDevices[device.id]?.stop()
    }

    private func getWorkoutDeviceSettings(device: WorkoutDevice) -> SettingsWorkoutDevice? {
        return database.workoutDevices.devices.first(where: { workoutDevices[$0.id] === device })
    }

    func setCurrentWorkoutDevice(device: SettingsWorkoutDevice) {
        currentWorkoutDeviceSettings = device
        statusTopRight.workoutDeviceState = getWorkoutDeviceState(device: device)
    }

    func getWorkoutDeviceState(device: SettingsWorkoutDevice) -> WorkoutDeviceState {
        return workoutDevices[device.id]?.getState() ?? .disconnected
    }

    func autoStartWorkoutDevices() {
        for device in database.workoutDevices.devices where device.enabled {
            enableWorkoutDevice(device: device)
        }
    }

    func stopWorkoutDevices() {
        for device in workoutDevices.values {
            device.stop()
        }
    }

    func isAnyWorkoutDeviceConfigured() -> Bool {
        return database.workoutDevices.devices.contains(where: { $0.enabled })
    }

    func areAllWorkoutDevicesConnected() -> Bool {
        return !workoutDevices.values.contains(where: {
            getWorkoutDeviceSettings(device: $0)?.enabled == true && $0.getState() != .connected
        })
    }
}

extension Model: WorkoutDeviceDelegate {
    func workoutDeviceState(_ device: WorkoutDevice, state: WorkoutDeviceState) {
        DispatchQueue.main.async {
            guard let device = self.getWorkoutDeviceSettings(device: device) else {
                return
            }
            self.heartRates.removeValue(forKey: device.name.lowercased())
            if device === self.currentWorkoutDeviceSettings {
                self.statusTopRight.workoutDeviceState = state
            }
        }
    }

    func workoutDeviceHeartRate(_ device: WorkoutDevice, heartRate: Int) {
        DispatchQueue.main.async {
            guard let device = self.getWorkoutDeviceSettings(device: device) else {
                return
            }
            self.heartRates[device.name.lowercased()] = heartRate
        }
    }
}
