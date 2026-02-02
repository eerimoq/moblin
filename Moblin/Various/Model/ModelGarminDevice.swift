import Foundation

private let metersPerMile = 1609.344

private func formatGarminDeviceState(state: GarminDeviceState?) -> String {
    if state == nil || state == .disconnected {
        return String(localized: "Disconnected")
    } else if state == .discovering {
        return String(localized: "Discovering")
    } else if state == .connecting {
        return String(localized: "Connecting")
    } else if state == .connected {
        return String(localized: "Connected")
    } else {
        return String(localized: "Unknown")
    }
}

extension SettingsGarminPaceUnit {
    var suffix: String {
        return rawValue
    }
}

extension SettingsGarminDistanceUnit {
    var suffix: String {
        return rawValue
    }
}

extension Model {
    func isGarminDeviceEnabled(device: SettingsGarminDevice) -> Bool {
        return device.enabled
    }

    func enableGarminDevice(device: SettingsGarminDevice) {
        if !garminDevices.keys.contains(device.id) {
            let garminDevice = GarminDevice()
            garminDevice.delegate = self
            garminDevices[device.id] = garminDevice
        }
        garminDevices[device.id]?.start(deviceId: device.bluetoothPeripheralId)
        updateGarminDeviceStatus()
    }

    func disableGarminDevice(device: SettingsGarminDevice) {
        garminDevices[device.id]?.stop()
        garminMetrics.removeValue(forKey: device.id)
        let deviceKey = device.name.lowercased()
        heartRates.removeValue(forKey: deviceKey)
        runMetricsByDeviceName.removeValue(forKey: deviceKey)
        updateGarminDeviceStatus()
    }

    private func getGarminDeviceSettings(device: GarminDevice) -> SettingsGarminDevice? {
        return database.garminDevices.devices.first(where: { garminDevices[$0.id] === device })
    }

    func setCurrentGarminDevice(device: SettingsGarminDevice) {
        currentGarminDeviceSettings = device
        statusTopRight.garminDeviceState = getGarminDeviceState(device: device)
        updateGarminDeviceStatus()
    }

    func getGarminDeviceState(device: SettingsGarminDevice) -> GarminDeviceState {
        return garminDevices[device.id]?.getState() ?? .disconnected
    }

    func autoStartGarminDevices() {
        for device in database.garminDevices.devices where device.enabled {
            enableGarminDevice(device: device)
        }
    }

    func stopGarminDevices() {
        for device in garminDevices.values {
            device.stop()
        }
    }

    func isAnyGarminDeviceConfigured() -> Bool {
        return database.garminDevices.devices.contains(where: { $0.enabled })
    }

    func areAllGarminDevicesConnected() -> Bool {
        return !garminDevices.values.contains(where: {
            getGarminDeviceSettings(device: $0)?.enabled == true && $0.getState() != .connected
        })
    }

    func resetGarminDistance(device: SettingsGarminDevice) {
        if let metrics = garminMetrics[device.id], let distance = metrics.distanceMeters {
            garminDistanceOffsets[device.id] = distance
        } else {
            garminDistanceOffsets[device.id] = 0
        }
    }

    private func updateGarminDeviceStatus() {
        let enabledDevices = database.garminDevices.devices.filter { $0.enabled }
        guard !enabledDevices.isEmpty else {
            statusTopRight.garminDeviceStatus = noValue
            return
        }
        if enabledDevices.count == 1, let device = enabledDevices.first {
            let state = garminDevices[device.id]?.getState()
            statusTopRight.garminDeviceStatus = formatGarminDeviceState(state: state)
            return
        }
        let connectedCount = enabledDevices.filter {
            garminDevices[$0.id]?.getState() == .connected
        }.count
        statusTopRight.garminDeviceStatus = "\(connectedCount)/\(enabledDevices.count)"
    }

    private func currentGarminDeviceAndMetrics() -> (SettingsGarminDevice, GarminMetrics)? {
        if let currentGarminDeviceSettings,
           let metrics = garminMetrics[currentGarminDeviceSettings.id]
        {
            return (currentGarminDeviceSettings, metrics)
        }
        if let device = database.garminDevices.devices.first(where: { $0.enabled }),
           let metrics = garminMetrics[device.id]
        {
            return (device, metrics)
        }
        return nil
    }

    func garminHeartRate() -> Int? {
        return currentGarminDeviceAndMetrics()?.1.heartRate
    }

    func garminPaceString() -> String {
        guard let (_, metrics) = currentGarminDeviceAndMetrics(),
              let speed = metrics.speedMetersPerSecond,
              speed > 0
        else {
            return "-"
        }
        let secondsPerUnit: Double
        switch database.garminUnits.paceUnit {
        case .minutesPerKilometer:
            secondsPerUnit = 1000.0 / speed
        case .minutesPerMile:
            secondsPerUnit = metersPerMile / speed
        }
        let totalSeconds = max(0, Int(secondsPerUnit.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let paceValue = String(format: "%d:%02d", minutes, seconds)
        return "\(paceValue) \(database.garminUnits.paceUnit.suffix)"
    }

    func garminCadenceString() -> String {
        guard let (_, metrics) = currentGarminDeviceAndMetrics(),
              let cadence = metrics.cadence
        else {
            return "-"
        }
        return "\(cadence) spm"
    }

    func garminDistanceString() -> String {
        guard let (device, metrics) = currentGarminDeviceAndMetrics(),
              let distanceMetersRaw = metrics.distanceMeters
        else {
            return "-"
        }
        let offset = garminDistanceOffsets[device.id] ?? 0
        let distanceMeters = max(0, distanceMetersRaw - offset)
        let value: Double
        switch database.garminUnits.distanceUnit {
        case .kilometers:
            value = distanceMeters / 1000.0
        case .miles:
            value = distanceMeters / metersPerMile
        }
        let formatted = String(format: "%.2f", value)
        return "\(formatted) \(database.garminUnits.distanceUnit.suffix)"
    }
}

extension Model: GarminDeviceDelegate {
    func garminDeviceState(_ device: GarminDevice, state: GarminDeviceState) {
        DispatchQueue.main.async {
            guard let device = self.getGarminDeviceSettings(device: device) else {
                return
            }
            if state != .connected {
                self.garminMetrics.removeValue(forKey: device.id)
                let deviceKey = device.name.lowercased()
                self.heartRates.removeValue(forKey: deviceKey)
                self.runMetricsByDeviceName.removeValue(forKey: deviceKey)
            }
            if device === self.currentGarminDeviceSettings {
                self.statusTopRight.garminDeviceState = state
            }
            self.updateGarminDeviceStatus()
        }
    }

    func garminMetrics(_ device: GarminDevice, metrics: GarminMetrics) {
        DispatchQueue.main.async {
            guard let device = self.getGarminDeviceSettings(device: device) else {
                return
            }
            self.garminMetrics[device.id] = metrics
            let deviceKey = device.name.lowercased()
            if let heartRate = metrics.heartRate {
                self.heartRates[deviceKey] = heartRate
            }
            var paceSecondsPerUnit: Double?
            if let speed = metrics.speedMetersPerSecond, speed > 0 {
                switch self.database.garminUnits.paceUnit {
                case .minutesPerKilometer:
                    paceSecondsPerUnit = 1000.0 / speed
                case .minutesPerMile:
                    paceSecondsPerUnit = metersPerMile / speed
                }
            }
            self.runMetricsByDeviceName[deviceKey] = DeviceRunMetrics(
                paceSecondsPerUnit: paceSecondsPerUnit,
                cadence: metrics.cadence,
                distanceMeters: metrics.distanceMeters
            )
        }
    }
}
