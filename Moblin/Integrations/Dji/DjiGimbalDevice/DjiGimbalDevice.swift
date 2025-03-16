import CoreBluetooth
import Foundation

private let djiGimbalDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.dji-gimbal-device")

private let serviceId = CBUUID(string: "FFF0")
private let fff5Id = CBUUID(string: "FFF5")

private let buttonsType: UInt32 = 0x570440
private let zoomType: UInt32 = 0x690440

enum DjiGimbalDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

protocol DjiGimbalDeviceDelegate: AnyObject {
    func djiGimbalDeviceStateChange(_ device: DjiGimbalDevice, state: DjiGimbalDeviceState)
    func djiGimbalDeviceTriggerButtonPressed(_ device: DjiGimbalDevice, press: DjiGimbalTriggerButtonPress)
    func djiGimbalDeviceSwitchSceneButtonPressed(_ device: DjiGimbalDevice)
    func djiGimbalDeviceRecordButtonPressed(_ device: DjiGimbalDevice)
}

class DjiGimbalDevice: NSObject {
    private var deviceId: UUID?
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var fff5Characteristic: CBCharacteristic?
    private var state: DjiGimbalDeviceState = .disconnected
    weak var delegate: (any DjiGimbalDeviceDelegate)?

    func start(deviceId: UUID?, model _: SettingsDjiGimbalDeviceModel) {
        logger.info("dji-gimbal-device: Start")
        djiGimbalDeviceDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        logger.info("dji-gimbal-device: Stop")
        djiGimbalDeviceDispatchQueue.async {
            self.stopInternal()
        }
    }

    func getState() -> DjiGimbalDeviceState {
        return state
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
        fff5Characteristic = nil
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        fff5Characteristic = nil
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: djiGimbalDeviceDispatchQueue)
    }

    private func setState(state: DjiGimbalDeviceState) {
        guard state != self.state else {
            return
        }
        logger.info("dji-gimbal-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.djiGimbalDeviceStateChange(self, state: state)
    }
}

extension DjiGimbalDevice: CBCentralManagerDelegate {
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
        peripheral.discoverServices([serviceId])
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
        reconnect()
    }
}

extension DjiGimbalDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        guard let peripheralServices = peripheral.services else {
            return
        }
        for service in peripheralServices {
            // logger.info("dji-gimbal-device: Service \(service)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == fff5Id {
                fff5Characteristic = characteristic
            }
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        if fff5Characteristic != nil {
            setState(state: .connected)
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        guard let message = try? DjiMessage(data: value) else {
            logger.info("dji-gimbal-device: \(characteristic.uuid): Discarding corrupt message \(value.hexString())")
            return
        }
        if message.type == zoomType {
            if let zoomMessage = DjiGimbalZoomMessagePayload(data: message.payload) {
                logger.info("dji-gimbal-device: Got zoom \(zoomMessage)")
            }
        } else if message.type == buttonsType {
            if let buttonsMessage = DjiGimbalButtonsMessagePayload(data: message.payload) {
                if let trigger = buttonsMessage.trigger {
                    delegate?.djiGimbalDeviceTriggerButtonPressed(self, press: trigger)
                }
                if buttonsMessage.switchScene {
                    delegate?.djiGimbalDeviceSwitchSceneButtonPressed(self)
                }
                if buttonsMessage.record {
                    delegate?.djiGimbalDeviceRecordButtonPressed(self)
                }
            }
        }
    }

    // periphery:ignore
    private func writeMessage(message: DjiMessage) {
        logger.info("dji-gimbal-device: Send \(message.format())")
        writeValue(value: message.encode())
    }

    // periphery:ignore
    private func writeValue(value: Data) {
        guard let fff5Characteristic else {
            return
        }
        peripheral?.writeValue(value, for: fff5Characteristic, type: .withoutResponse)
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateNotificationStateFor _: CBCharacteristic,
        error _: Error?
    ) {}

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {}
}
