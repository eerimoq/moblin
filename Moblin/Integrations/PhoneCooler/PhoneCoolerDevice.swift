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
    func phoneCoolerStatus(_ device: PhoneCoolerDevice, status: BlackSharkLib.CoolingState)
}

enum PhoneCoolerDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private let phoneCoolerServiceId = CBUUID(string: BlackSharkLib.getServiceUUID().uuidString)

let phoneCoolerScanner = BluetoothScanner(serviceIds: [])

class PhoneCoolerDevice: NSObject {
    private var state: PhoneCoolerDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var deviceId: UUID?
    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    private var latestTransmissionTime = ContinuousClock.now
    private var coolingStatsTimer = SimpleTimer(queue: phoneCoolerDeviceDispatchQueue)
    private var coolingPower: Int? // 0-100% How much the cooler should cool.
    private var fanSpeed: Int? // 0-100% How much the fan should spin.
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
        coolingStatsTimer.stop()
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

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
        reconnect()
    }
}

extension PhoneCoolerDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == phoneCoolerServiceId }) {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            logger.debug("phone-cooler-device: Characteristic found: \(characteristic.uuid)")
            switch characteristic.uuid {
            case CBUUID(data: BlackSharkLib.getReadCharacteristicsUUID()):
                readCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case CBUUID(data: BlackSharkLib.getWriteCharacteristicsUUID()):
                writeCharacteristic = characteristic
                pollForCoolingStats()
                coolingStatsTimer.startPeriodic(interval: 2) { [weak self] in
                    self?.pollForCoolingStats()
                }
            default:
                break
            }
        }
        if readCharacteristic != nil {
            setState(state: .connected)
        }
    }

    private func updatedPercentageScale(_ current: Int?, target: Int) -> Int {
        guard let current else {
            return target
        }
        if current > target {
            return max(current - 5, target)
        } else if current < target {
            return min(current + 5, target)
        } else {
            return target
        }
    }

    private func pollForCoolingStats() {
        guard let peripheral, let writeCharacteristic else {
            return
        }
        peripheral.writeValue(
            BlackSharkLib.getCoolingMetadataCommand(),
            for: writeCharacteristic,
            type: .withoutResponse
        )
        let coolingPowerTarget: Int
        let fanSpeedTarget: Int
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            coolingPowerTarget = 5
            fanSpeedTarget = 15
        case .fair:
            coolingPowerTarget = 20
            fanSpeedTarget = 20
        case .serious:
            coolingPowerTarget = 80
            fanSpeedTarget = 50
        case .critical:
            coolingPowerTarget = 100
            fanSpeedTarget = 100
        @unknown default:
            coolingPowerTarget = 100
            fanSpeedTarget = 100
            logger.warning("phone-cooler-device: Thermal state is unknown value")
        }
        // Since we do not know the fan and cooler-state we have to assume that it can be out of sync. sending the
        // commands to update the cooling power and fan speed on every interval will make sure that its in sync.
        let coolingPower = updatedPercentageScale(coolingPower, target: coolingPowerTarget)
        logger.debug("phone-cooler-device: Adjusting cooling power to \(coolingPower) %")
        peripheral.writeValue(
            BlackSharkLib.getSetCoolingPowerCommand(coolingPower)!,
            for: writeCharacteristic,
            type: .withoutResponse
        )
        let fanSpeed = updatedPercentageScale(fanSpeed, target: fanSpeedTarget)
        logger.debug("phone-cooler-device: Adjusting fan speed to \(fanSpeed) %")
        peripheral.writeValue(
            BlackSharkLib.getSetFanSpeedCommand(fanSpeed)!,
            for: writeCharacteristic,
            type: .withoutResponse
        )
    }

    func setLedColor(color: RgbColor, brightness: Int) {
        let now = ContinuousClock.now
        guard latestTransmissionTime.duration(to: now) >= .milliseconds(80) else {
            return
        }
        latestTransmissionTime = now
        guard let setColorCommand = BlackSharkLib.getSetLEDColorCommand(
            color.red,
            color.green,
            color.blue,
            brightness: brightness
        ) else {
            return
        }
        guard let peripheral, let writeCharacteristic else {
            return
        }
        peripheral.writeValue(setColorCommand, for: writeCharacteristic, type: .withoutResponse)
    }

    func turnLedOff() {
        guard let peripheral, let writeCharacteristic else {
            return
        }
        peripheral.writeValue(BlackSharkLib.getTurnOffLEDCommand(), for: writeCharacteristic, type: .withoutResponse)
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        switch characteristic.uuid {
        case CBUUID(data: BlackSharkLib.getReadCharacteristicsUUID()):
            let message = BlackSharkLib.parseMessages(value)
            if let coolingState = message as? BlackSharkLib.CoolingState {
                delegate?.phoneCoolerStatus(self, status: coolingState)
                logger.debug("""
                phone-cooler-device: CoolerTemp:\(coolingState.phoneTemperature), \
                Heatsink: \(coolingState.heatsinkTemperature)
                """)
            }
        default:
            break
        }
    }
}
