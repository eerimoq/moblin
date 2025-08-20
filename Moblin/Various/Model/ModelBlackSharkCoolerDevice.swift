//
//  ModelBlackSharkCoolerDevice.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import BlackSharkLib
import Foundation

extension Model {
    func enableBlackSharkDevice(device: SettingsBlackSharkCoolerDevice) {
        if !blackSharkCoolerDevices.keys.contains(device.bluetoothPeripheralId!) {
            let blackSharkCoolerDevice = BlackSharkCoolerDevice()
            blackSharkCoolerDevice.delegate = self
            blackSharkCoolerDevices[device.bluetoothPeripheralId!] = blackSharkCoolerDevice
        }
        blackSharkCoolerDevices[device.bluetoothPeripheralId!]?.start(deviceId: device.bluetoothPeripheralId)
    }

    func disableBlackSharkCoolerDevice(device: SettingsBlackSharkCoolerDevice) {
        blackSharkCoolerDevices[device.id]?.stop()
    }
}

extension Model: BlackSharkCoolerDeviceDelegate {
    func blackSharkCoolerDeviceState(_: BlackSharkCoolerDevice, state: BlackSharkCoolerDeviceState) {
        DispatchQueue.main.async {
            self.statusTopRight.blackSharkCoolerDeviceState = state
        }
    }

    func blackSharkCoolerDeviceStatus(_: BlackSharkCoolerDevice, status: BlackSharkLib.CoolingState) {
        DispatchQueue.main.async {
            self.statusTopRight.blackSharkCoolerPhoneTemp = status.phoneTemperature
            self.statusTopRight.blackSharkCoolerExhaustTemp = status.heatsinkTemperature
        }
    }

    func autoStartBlackSharkCoolerDevices() {
        for device in database.blackSharkCoolerDevices.devices where device.enabled {
            enableBlackSharkDevice(device: device)
        }
    }
}
