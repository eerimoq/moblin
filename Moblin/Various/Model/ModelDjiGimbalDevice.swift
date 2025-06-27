import Foundation

extension Model {
    func isDjiGimbalDeviceEnabled(device: SettingsDjiGimbalDevice) -> Bool {
        return device.enabled
    }

    func enableDjiGimbalDevice(device: SettingsDjiGimbalDevice) {
        if !djiGimbalDevices.keys.contains(device.id) {
            let djiDevice = DjiGimbalDevice()
            djiDevice.delegate = self
            djiGimbalDevices[device.id] = djiDevice
        }
        djiGimbalDevices[device.id]?.start(deviceId: device.bluetoothPeripheralId, model: device.model)
    }

    func disableDjiGimbalDevice(device: SettingsDjiGimbalDevice) {
        djiGimbalDevices[device.id]?.stop()
    }

    func setCurrentDjiGimbalDevice(device: SettingsDjiGimbalDevice) {
        currentDjiGimbalDeviceSettings = device
        status.djiGimbalDeviceStreamingState = getDjiGimbalDeviceState(device: device)
    }

    private func getDjiGimbalDeviceSettings(djiDevice: DjiGimbalDevice) -> SettingsDjiGimbalDevice? {
        return database.djiGimbalDevices.devices.first(where: { djiGimbalDevices[$0.id] === djiDevice })
    }

    func getDjiGimbalDeviceState(device: SettingsDjiGimbalDevice) -> DjiGimbalDeviceState? {
        return djiGimbalDevices[device.id]?.getState()
    }

    func autoStartDjiGimbalDevices() {
        for device in database.djiGimbalDevices.devices where device.enabled {
            enableDjiGimbalDevice(device: device)
        }
    }

    func stopDjiGimbalDevices() {
        for djiDevice in djiGimbalDevices.values {
            djiDevice.stop()
        }
    }

    func removeDjiGimbalDevices(offsets: IndexSet) {
        for offset in offsets {
            let device = database.djiGimbalDevices.devices[offset]
            djiGimbalDevices.removeValue(forKey: device.id)
        }
        database.djiGimbalDevices.devices.remove(atOffsets: offsets)
    }
}

extension Model: DjiGimbalDeviceDelegate {
    func djiGimbalDeviceStateChange(_ device: DjiGimbalDevice, state: DjiGimbalDeviceState) {
        DispatchQueue.main.async {
            guard let device = self.getDjiGimbalDeviceSettings(djiDevice: device) else {
                return
            }
            if device === self.currentDjiGimbalDeviceSettings {
                self.status.djiGimbalDeviceStreamingState = state
            }
        }
    }

    func djiGimbalDeviceTriggerButtonPressed(_: DjiGimbalDevice, press: DjiGimbalTriggerButtonPress) {
        DispatchQueue.main.async {
            switch press {
            case .single:
                self.makeToast(title: "Gimbal trigger button single press")
            case .double:
                self.makeToast(title: "Gimbal trigger button double press")
            case .triple:
                self.makeToast(title: "Gimbal trigger button triple press")
            case .long:
                self.makeToast(title: "Gimbal trigger button long press")
            }
        }
    }

    func djiGimbalDeviceSwitchSceneButtonPressed(_: DjiGimbalDevice) {
        DispatchQueue.main.async {
            self.makeToast(title: "Gimbal switch scene button pressed")
        }
    }

    func djiGimbalDeviceRecordButtonPressed(_: DjiGimbalDevice) {
        DispatchQueue.main.async {
            self.toggleRecording()
        }
    }
}
