import Foundation

extension Model {
    func isWorkoutDeviceEnabled(device: SettingsWorkoutDevice) -> Bool {
        device.enabled
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
        database.workoutDevices.devices.first(where: { workoutDevices[$0.id] === device })
    }

    func setCurrentWorkoutDevice(device: SettingsWorkoutDevice) {
        currentWorkoutDeviceSettings = device
        statusTopRight.workoutDeviceState = getWorkoutDeviceState(device: device)
    }

    func getWorkoutDeviceState(device: SettingsWorkoutDevice) -> WorkoutDeviceState {
        workoutDevices[device.id]?.getState() ?? .disconnected
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
        database.workoutDevices.devices.contains(where: \.enabled)
    }

    func areAllWorkoutDevicesConnected() -> Bool {
        !workoutDevices.values.contains(where: {
            getWorkoutDeviceSettings(device: $0)?.enabled == true && $0.getState() != .connected
        })
    }
}

extension Model: @preconcurrency WorkoutDeviceDelegate {
    func workoutDeviceState(_ device: WorkoutDevice, state: WorkoutDeviceState) {
        DispatchQueue.main.async {
            guard let device = self.getWorkoutDeviceSettings(device: device) else {
                return
            }
            let deviceName = device.name.lowercased()
            self.heartRates.removeValue(forKey: deviceName)
            self.runningMetrics.removeValue(forKey: deviceName)
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

    func workoutDeviceCyclingPower(_: WorkoutDevice, power: Int, cadence: Int) {
        DispatchQueue.main.async {
            self.cyclingPower = power
            self.cyclingCadence = cadence
        }
    }

    func workoutDeviceRunningMetrics(_ device: WorkoutDevice, metrics: WorkoutDeviceRunningMetrics) {
        DispatchQueue.main.async {
            guard let device = self.getWorkoutDeviceSettings(device: device) else {
                return
            }
            self.runningMetrics[device.name.lowercased()] = metrics
        }
    }
}
