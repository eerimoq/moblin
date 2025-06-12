//
//  PhoneCoolerDevice.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//
import BlackSharkLib
import CoreBluetooth
import Foundation

private let phoneCoolerDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.phone-cooler-device")

protocol PhoneCoolerDeviceDelegate: AnyObject {
    func phoneCoolerDeviceState(_ device: PhoneCoolerDevice, state: PhoneCoolerDeviceState)

    func phoneCoolerStatus(
        _ device: PhoneCoolerDevice,
        status: BlackSharkLib.CoolingState
    )
}

enum PhoneCoolerDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private let phoneCoolerServiceId = CBUUID(string: BlackSharkLib.getServiceUUID().uuidString)

let phoneCoolerScanner = BluetoothScanner(
    serviceIds: []
)

class PhoneCoolerDevice: NSObject {
    private var state: PhoneCoolerDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var deviceId: UUID?

    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?

    var lastTransmission: Date = .distantPast

    var coolingStatsTimer: Timer?

    var coolingPower: Int? // 0-100% How much the cooler should cool.
    var fanSpeed: Int? // 0-100% How much the fan should spin.

    weak var delegate: (any PhoneCoolerDeviceDelegate)?

    func start(deviceId: UUID?) {
        phoneCoolerDeviceDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        phoneCoolerDeviceDispatchQueue.async {
            self.stopInternal()
        }
    }

    private func startInternal(deviceId: UUID?) {
        self.deviceId = deviceId
        reset()
        reconnect()
    }

    private func stopInternal() {
        reset()
    }

    private func reset() {
        centralManager = nil
        peripheral = nil
        readCharacteristic = nil
        writeCharacteristic = nil
        coolingStatsTimer?.invalidate()
        coolingStatsTimer = nil
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: phoneCoolerDeviceDispatchQueue)
    }

    private func setState(state: PhoneCoolerDeviceState) {
        guard state != self.state else {
            return
        }
        logger.debug("phone-cooler-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.phoneCoolerDeviceState(self, state: state)
    }
}

extension PhoneCoolerDevice: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager?.scanForPeripherals(withServices: nil)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData _: [String: Any],
                        rssi _: NSNumber)
    {
        guard peripheral.identifier == deviceId else {
            return
        }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {}

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral _: CBPeripheral,
        error _: Error?
    ) {
        reconnect()
    }
}

extension PhoneCoolerDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == phoneCoolerServiceId }) {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    // Find characteristics
    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            logger.debug("Characteristic foudn: \(characteristic.uuid)")
            switch characteristic.uuid {
            case CBUUID(data: BlackSharkLib.getReadCharacteristicsUUID()):
                readCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)

            case CBUUID(data: BlackSharkLib.getWriteCharacteristicsUUID()):
                writeCharacteristic = characteristic

                pollForCoolingStats()
                DispatchQueue.main.async {
                    self.coolingStatsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                        self.pollForCoolingStats()
                    }
                }

            default:
                break
            }
        }
        if readCharacteristic != nil {
            setState(state: .connected)
        }
    }

    func updatedPercentageScale(_ value: Int?, target: Int) -> Int {
        guard let current = value else {
            return target
        }
        if current > target {
            let newValue = current - 5
            return newValue < target ? target : newValue
        } else if current < target {
            let newValue = current + 5
            return newValue > target ? target : newValue
        } else {
            return target
        }
    }

    private func pollForCoolingStats() {
        guard writeCharacteristic != nil else {
            return
        }
        peripheral?.writeValue(
            BlackSharkLib.getCoolingMetadataCommand(),
            for: writeCharacteristic!,
            type: .withoutResponse
        )
        // Get thermal state of phone
        let thermalState = ProcessInfo.processInfo.thermalState

        switch thermalState {
        case .nominal:
            // Cooling: 10%, Fan: 10%
            let updatedCoolingPower = updatedPercentageScale(coolingPower, target: 5)
            if updatedCoolingPower != coolingPower {
                coolingPower = updatedCoolingPower
                logger.debug("Phone is Nominal. Adjusting cooling power to \(String(coolingPower!)) %")
            }
            let updatedFanSpeed = updatedPercentageScale(fanSpeed, target: 15)
            if updatedFanSpeed != fanSpeed {
                fanSpeed = updatedFanSpeed
                logger.debug("Phone is nominal. Adjusting fan speed to \(String(fanSpeed!)) %")
            }
        case .fair:
            // Cooling: 20%, Fan: 20%
            let updatedCoolingPower = updatedPercentageScale(coolingPower, target: 20)
            if updatedCoolingPower != coolingPower {
                coolingPower = updatedCoolingPower
                logger.debug("Phone is fair. Adjusting cooling power to \(String(coolingPower!)) %")
            }
            let updatedFanSpeed = updatedPercentageScale(fanSpeed, target: 20)
            if updatedFanSpeed != fanSpeed {
                fanSpeed = updatedFanSpeed
                logger.debug("Phone is fair. Adjusting fan speed to \(String(fanSpeed!)) %")
            }
        case .serious:
            // Cooling: 80%, Fan: 50%
            let updatedCoolingPower = updatedPercentageScale(coolingPower, target: 80)
            if updatedCoolingPower != coolingPower {
                coolingPower = updatedCoolingPower
                logger.debug("Phone is serious. Adjusting cooling power to \(String(coolingPower!)) %")
            }
            let updatedFanSpeed = updatedPercentageScale(fanSpeed, target: 50)
            if updatedFanSpeed != fanSpeed {
                fanSpeed = updatedFanSpeed
                logger.debug("Phone is serious. Adjusting fan speed to \(String(fanSpeed!)) %")
            }
        case .critical:
            // Cooling: 100%, Fan: 100%
            let updatedCoolingPower = updatedPercentageScale(coolingPower, target: 100)
            if updatedCoolingPower != coolingPower {
                coolingPower = updatedCoolingPower
                logger.debug("Phone is critical. Adjusting cooling power to \(String(coolingPower!)) %")
            }
            let updatedFanSpeed = updatedPercentageScale(fanSpeed, target: 100)
            if updatedFanSpeed != fanSpeed {
                fanSpeed = updatedFanSpeed
                logger.debug("Phone is faCritical. Adjusting fan speed to \(String(fanSpeed!)) %")
            }
        @unknown default:
            logger.warning("Thermal state is Unkonwn value")
        }

        peripheral?.writeValue(
            BlackSharkLib.getSetFanSpeedCommand(fanSpeed!)!,
            for: writeCharacteristic!,
            type: .withoutResponse
        )

        peripheral?.writeValue(
            BlackSharkLib.getSetCoolingPowerCommand(coolingPower!)!,
            for: writeCharacteristic!,
            type: .withoutResponse
        )
    }

    func setLEDColor(red: Int, green: Int, blue: Int, brightness: Int) {
        let cooldown: TimeInterval = 0.08
        let now = Date()

        guard now.timeIntervalSince(lastTransmission) >= cooldown else {
            return
        }

        lastTransmission = .now

        let setColorCommand = BlackSharkLib.getSetLEDColorCommand(red, green, blue, brightness: brightness)!
        print(setColorCommand.hexString())
        peripheral?.writeValue(setColorCommand, for: writeCharacteristic!, type: .withoutResponse)
    }

    func turnLEdOff() {
        peripheral?.writeValue(BlackSharkLib.getTurnOffLEDCommand(), for: writeCharacteristic!, type: .withoutResponse)
    }

    // Read updates
    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }

        switch characteristic.uuid {
        case CBUUID(data: BlackSharkLib.getReadCharacteristicsUUID()):
            let message = BlackSharkLib.parseMessages(value)
            if let coolingstate = message as? BlackSharkLib.CoolingState {
                delegate?.phoneCoolerStatus(self, status: coolingstate)
                logger
                    .debug(
                        "CoolerTemp:\(coolingstate.phoneTemperature), Heatsink: \(coolingstate.heatsinkTemperature)"
                    )
            }
        default:
            break
        }
    }
}
