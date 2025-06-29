import Foundation

extension Model {
    func isCyclingPowerDeviceEnabled(device: SettingsCyclingPowerDevice) -> Bool {
        return device.enabled
    }

    func enableCyclingPowerDevice(device: SettingsCyclingPowerDevice) {
        if !cyclingPowerDevices.keys.contains(device.id) {
            let cyclingPowerDevice = CyclingPowerDevice()
            cyclingPowerDevice.delegate = self
            cyclingPowerDevices[device.id] = cyclingPowerDevice
        }
        cyclingPowerDevices[device.id]?.start(deviceId: device.bluetoothPeripheralId)
    }

    func disableCyclingPowerDevice(device: SettingsCyclingPowerDevice) {
        cyclingPowerDevices[device.id]?.stop()
    }

    private func getCyclingPowerDeviceSettings(device: CyclingPowerDevice) -> SettingsCyclingPowerDevice? {
        return database.cyclingPowerDevices.devices.first(where: { cyclingPowerDevices[$0.id] === device })
    }

    func setCurrentCyclingPowerDevice(device: SettingsCyclingPowerDevice) {
        currentCyclingPowerDeviceSettings = device
        statusTopRight.cyclingPowerDeviceState = getCyclingPowerDeviceState(device: device)
    }

    func getCyclingPowerDeviceState(device: SettingsCyclingPowerDevice) -> CyclingPowerDeviceState {
        return cyclingPowerDevices[device.id]?.getState() ?? .disconnected
    }

    func autoStartCyclingPowerDevices() {
        for device in database.cyclingPowerDevices.devices where device.enabled {
            enableCyclingPowerDevice(device: device)
        }
    }

    func stopCyclingPowerDevices() {
        for device in cyclingPowerDevices.values {
            device.stop()
        }
    }

    func isAnyCyclingPowerDeviceConfigured() -> Bool {
        return database.cyclingPowerDevices.devices.contains(where: { $0.enabled })
    }

    func areAllCyclingPowerDevicesConnected() -> Bool {
        return !cyclingPowerDevices.values.contains(where: {
            getCyclingPowerDeviceSettings(device: $0)?.enabled == true && $0.getState() != .connected
        })
    }
}

extension Model: CyclingPowerDeviceDelegate {
    func cyclingPowerDeviceState(_ device: CyclingPowerDevice, state: CyclingPowerDeviceState) {
        DispatchQueue.main.async {
            guard let device = self.getCyclingPowerDeviceSettings(device: device) else {
                return
            }
            if device === self.currentCyclingPowerDeviceSettings {
                self.statusTopRight.cyclingPowerDeviceState = state
            }
        }
    }

    func cyclingPowerStatus(_: CyclingPowerDevice, power: Int, cadence: Int) {
        DispatchQueue.main.async {
            self.cyclingPower = power
            self.cyclingCadence = cadence
        }
    }
}
