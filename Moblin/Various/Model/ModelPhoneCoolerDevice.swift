//
//  ModelPhoneCoolerDevice.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import Foundation
import BlackSharkLib

extension Model {
    

    
    func enablePhoneCoolerDevice(device: SettingsPhoneCoolerDevice){
        if !phoneCoolerDevices.keys.contains(device.id) {
            let phoneCoolerDevice = PhoneCoolerDevice()
            phoneCoolerDevice.delegate = self
            phoneCoolerDevices[device.id] = phoneCoolerDevice
        }
        phoneCoolerDevices[device.id]?.start(deviceId: device.bluetoothPeripheralId)
    }
    
    func disablePhoneCoolerDevice(device: SettingsPhoneCoolerDevice){
        phoneCoolerDevices[device.id]?.stop()
    }
    
}

extension Model: PhoneCoolerDeviceDelegate {
    func phoneCoolerDeviceState(_ device: PhoneCoolerDevice, state: PhoneCoolerDeviceState) {
        logger.debug("Getting Phone Cooler State: \(state)")
        DispatchQueue.main.async{
            self.phoneCoolerDeviceState = state
        }
        
    }
    
    func phoneCoolerStatus(_ device: PhoneCoolerDevice, status: BlackSharkLib.CoolingState) {
        DispatchQueue.main.async {
            self.phoneCoolerPhoneTemp = status.phoneTemperature
            self.phoneCoolerExhaustTemp = status.heatsinkTemperature
        }
    }
    
    func autoStartPhoneCoolerDevices() {
        for device in database.phoneCoolerDevices.devices where device.enabled {
            enablePhoneCoolerDevice(device: device)
        }
    }
    
}
