import Foundation

extension Model {
    func isHeartRateDeviceEnabled(device: SettingsHeartRateDevice) -> Bool {
        return device.enabled
    }

    func enableHeartRateDevice(device: SettingsHeartRateDevice) {
        if !heartRateDevices.keys.contains(device.id) {
            let heartRateDevice = HeartRateDevice()
            heartRateDevice.delegate = self
            heartRateDevices[device.id] = heartRateDevice
        }
        heartRateDevices[device.id]?.start(deviceId: device.bluetoothPeripheralId)
    }

    func disableHeartRateDevice(device: SettingsHeartRateDevice) {
        heartRateDevices[device.id]?.stop()
    }

    private func getHeartRateDeviceSettings(device: HeartRateDevice) -> SettingsHeartRateDevice? {
        return database.heartRateDevices.devices.first(where: { heartRateDevices[$0.id] === device })
    }

    func setCurrentHeartRateDevice(device: SettingsHeartRateDevice) {
        currentHeartRateDeviceSettings = device
        statusTopRight.heartRateDeviceState = getHeartRateDeviceState(device: device)
    }

    func getHeartRateDeviceState(device: SettingsHeartRateDevice) -> HeartRateDeviceState {
        return heartRateDevices[device.id]?.getState() ?? .disconnected
    }

    func autoStartHeartRateDevices() {
        for device in database.heartRateDevices.devices where device.enabled {
            enableHeartRateDevice(device: device)
        }
    }

    func stopHeartRateDevices() {
        for device in heartRateDevices.values {
            device.stop()
        }
    }

    func isAnyHeartRateDeviceConfigured() -> Bool {
        return database.heartRateDevices.devices.contains(where: { $0.enabled })
    }

    func areAllHeartRateDevicesConnected() -> Bool {
        return !heartRateDevices.values.contains(where: {
            getHeartRateDeviceSettings(device: $0)?.enabled == true && $0.getState() != .connected
        })
    }
}

extension Model: HeartRateDeviceDelegate {
    func heartRateDeviceState(_ device: HeartRateDevice, state: HeartRateDeviceState) {
        DispatchQueue.main.async {
            guard let device = self.getHeartRateDeviceSettings(device: device) else {
                return
            }
            self.heartRates.removeValue(forKey: device.name.lowercased())
            if device === self.currentHeartRateDeviceSettings {
                self.statusTopRight.heartRateDeviceState = state
            }
        }
    }

    func heartRateStatus(_ device: HeartRateDevice, heartRate: Int) {
        DispatchQueue.main.async {
            guard let device = self.getHeartRateDeviceSettings(device: device) else {
                return
            }
            self.heartRates[device.name.lowercased()] = heartRate
        }
    }
}
