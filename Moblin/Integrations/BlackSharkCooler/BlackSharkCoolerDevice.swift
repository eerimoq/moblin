//
//  BlackSharkCoolerDevice.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//
import BlackSharkLib
@preconcurrency import CoreBluetooth
import Foundation

private let blackSharkCoolerDeviceDispatchQueue =
    DispatchQueue(label: "com.eerimoq.black-shark-cooler-device")

protocol BlackSharkCoolerDeviceDelegate: AnyObject {
    func blackSharkCoolerDeviceState(_ device: BlackSharkCoolerDevice, state: BlackSharkCoolerDeviceState)
    func blackSharkCoolerDeviceStatus(_ device: BlackSharkCoolerDevice, status: BlackSharkLib.CoolingState)
}

enum BlackSharkCoolerDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private let blackSharkCoolerServiceId = CBUUID(string: BlackSharkLib.getServiceUUID().uuidString)

nonisolated(unsafe) let blackSharkCoolerScanner = BluetoothScanner(serviceIds: [])

class BlackSharkCoolerDevice: NSObject, @unchecked Sendable {
    private var state: BlackSharkCoolerDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var deviceId: UUID?
    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    private var latestTransmissionTime = ContinuousClock.now
    private var model: BlackSharkLib.Model?
    private var advertisedName: String?
    private var coolingStatsTimer = SimpleTimer(queue: blackSharkCoolerDeviceDispatchQueue)
    private var coolingPower: Int? // 0-100% How much the cooler should cool.
    private var fanSpeed: Int? // 0-100% How much the fan should spin.
    weak var delegate: (any BlackSharkCoolerDeviceDelegate)?

    func start(deviceId: UUID?) {
        blackSharkCoolerDeviceDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        blackSharkCoolerDeviceDispatchQueue.async {
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
        centralManager = CBCentralManager(delegate: self, queue: blackSharkCoolerDeviceDispatchQueue)
    }

    private func setState(state: BlackSharkCoolerDeviceState) {
        guard state != self.state else {
            return
        }
        logger.debug("black-shark-cooler-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.blackSharkCoolerDeviceState(self, state: state)
    }
}

extension BlackSharkCoolerDevice: CBCentralManagerDelegate {
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
                        advertisementData: [String: Any],
                        rssi _: NSNumber)
    {
        guard peripheral.identifier == deviceId else {
            return
        }
        central.stopScan()
        self.peripheral = peripheral
        advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: (any Error)?) {}

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: (any Error)?) {
        reconnect()
    }
}

extension BlackSharkCoolerDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: (any Error)?) {
        if let service = peripheral.services?.first(where: { $0.uuid == blackSharkCoolerServiceId }) {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: (any Error)?
    ) {
        model = BlackSharkLib.detectModel(advertisedName: advertisedName)
        for characteristic in service.characteristics ?? [] {
            logger.debug("black-shark-cooler-device: Characteristic found: \(characteristic.uuid)")
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
        guard let peripheral, let writeCharacteristic, let model else {
            return
        }
        peripheral.writeValue(
            BlackSharkLib.getCoolingMetadataCommand(model: model),
            for: writeCharacteristic,
            type: .withoutResponse
        )
    }

    func adjustCoolerProfile() {
        guard let peripheral, let writeCharacteristic, let model else {
            return
        }
        let thermalState = ProcessInfo.processInfo.thermalState
        switch model {
        case .pro4:
            let coolingPowerTarget: Int
            let fanSpeedTarget: Int
            switch thermalState {
            case .nominal:
                coolingPowerTarget = 0
                fanSpeedTarget = 10
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
                logger.info("black-shark-cooler-device: Thermal state is unknown value ( \(thermalState) )")
            }
            let coolingPower = updatedPercentageScale(coolingPower, target: coolingPowerTarget)
            logger.debug("black-shark-cooler-device (Pro 4): Adjusting cooling power to \(coolingPower)%")
            peripheral.writeValue(
                BlackSharkLib.getSetCoolingPowerCommand(coolingPower, model: model)!,
                for: writeCharacteristic,
                type: .withoutResponse
            )
            let fanSpeed = updatedPercentageScale(fanSpeed, target: fanSpeedTarget)
            logger.debug("black-shark-cooler-device (Pro 4): Adjusting fan speed to \(fanSpeed)%")
            peripheral.writeValue(
                BlackSharkLib.getSetFanSpeedCommand(fanSpeed, model: model)!,
                for: writeCharacteristic,
                type: .withoutResponse
            )
        case .pro5:
            switch thermalState {
            case .nominal:
                logger.debug("black-shark-cooler-device (Pro 5): Adjusting cooling power to OFF")
                peripheral.writeValue(
                    BlackSharkLib.getSetCoolingEnabledCommand(false, model: .pro5)!,
                    for: writeCharacteristic,
                    type: .withoutResponse
                )
            case .fair:
                if coolingPower != nil, coolingPower! == 2 {
                    logger.debug("black-shark-cooler-device (Pro 5): Enabling custom mode for cooler.")
                    peripheral.writeValue(
                        BlackSharkLib.getSetCoolingEnabledCommand(true, model: .pro5)!,
                        for: writeCharacteristic,
                        type: .withoutResponse
                    )
                }
                logger.debug("black-shark-cooler-device (Pro 5): Adjusting cooling power to 1")
                peripheral.writeValue(
                    BlackSharkLib.getSetCustomModeCommand(intensity: 1, model: .pro5)!,
                    for: writeCharacteristic,
                    type: .withoutResponse
                )
            case .serious:
                if coolingPower != nil, coolingPower! == 2 {
                    logger.debug("black-shark-cooler-device (Pro 5): Enabling custom mode for cooler.")
                    peripheral.writeValue(
                        BlackSharkLib.getSetCoolingEnabledCommand(true, model: .pro5)!,
                        for: writeCharacteristic,
                        type: .withoutResponse
                    )
                }
                logger.debug("black-shark-cooler-device (Pro 5): Adjusting cooling power to 3")
                peripheral.writeValue(
                    BlackSharkLib.getSetCustomModeCommand(intensity: 2, model: .pro5)!,
                    for: writeCharacteristic,
                    type: .withoutResponse
                )
            case .critical:
                if coolingPower != nil, coolingPower! == 2 {
                    logger.debug("black-shark-cooler-device (Pro 5): Enabling custom mode for cooler.")
                    peripheral.writeValue(
                        BlackSharkLib.getSetCoolingEnabledCommand(true, model: .pro5)!,
                        for: writeCharacteristic,
                        type: .withoutResponse
                    )
                }
                logger.debug("black-shark-cooler-device (Pro 5): Adjusting cooling power to 5")
                peripheral.writeValue(
                    BlackSharkLib.getSetCustomModeCommand(intensity: 5, model: .pro5)!,
                    for: writeCharacteristic,
                    type: .withoutResponse
                )
            @unknown default:
                if coolingPower != nil, coolingPower! == 2 {
                    logger.debug("black-shark-cooler-device (Pro 5): Enabling custom mode for cooler.")
                    peripheral.writeValue(
                        BlackSharkLib.getSetCoolingEnabledCommand(true, model: .pro5)!,
                        for: writeCharacteristic,
                        type: .withoutResponse
                    )
                }
                peripheral.writeValue(
                    BlackSharkLib.getSetCustomModeCommand(intensity: 5, model: .pro5)!,
                    for: writeCharacteristic,
                    type: .withoutResponse
                )
            }
        }
    }

    func setLedColor(color: RgbColor, brightness: Int) {
        guard let model else {
            return
        }
        let now = ContinuousClock.now
        guard latestTransmissionTime.duration(to: now) >= .milliseconds(80) else {
            return
        }
        latestTransmissionTime = now
        guard let setColorCommand = BlackSharkLib.getSetLEDColorCommand(
            color.red,
            color.green,
            color.blue,
            brightness: brightness,
            model: model
        ) else {
            return
        }
        guard let peripheral, let writeCharacteristic else {
            return
        }
        peripheral.writeValue(setColorCommand, for: writeCharacteristic, type: .withoutResponse)
    }

    func turnLedOff() {
        guard let peripheral, let writeCharacteristic, let model else {
            return
        }
        peripheral.writeValue(
            BlackSharkLib.getTurnOffLEDCommand(model: model),
            for: writeCharacteristic,
            type: .withoutResponse
        )
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error _: (any Error)?
    ) {
        guard let value = characteristic.value, let model else {
            return
        }
        switch characteristic.uuid {
        case CBUUID(data: BlackSharkLib.getReadCharacteristicsUUID()):
            let message = BlackSharkLib.parseMessages(value)
            if let coolingState = message as? BlackSharkLib.CoolingState {
                delegate?.blackSharkCoolerDeviceStatus(self, status: coolingState)
                switch model {
                case .pro4:
                    logger.debug("""
                    black-shark-cooler-device (4 Pro): CoolerTemp: \(coolingState.phoneTemperature), \
                    Heatsink: \(coolingState.heatsinkTemperature)
                    """)
                case .pro5:
                    logger.debug("""
                    black-shark-cooler-device (5 Pro): CoolerTemp: \(coolingState.phoneTemperature), \
                    Heatsink: \(coolingState.heatsinkTemperature), \
                    Fan: \(coolingState.fanRPM.map(String.init) ?? "n/a"), \
                    Power: \(coolingState.powerLevel.map(String.init) ?? "n/a")
                    """)
                }
                adjustCoolerProfile()
            } else if let unknown = message as? BlackSharkLib.UnknownMessage {
                logger.debug("black-shark-cooler-device: Got unknown message \(unknown.rawData.hexString())")
            }
        default:
            break
        }
    }
}
