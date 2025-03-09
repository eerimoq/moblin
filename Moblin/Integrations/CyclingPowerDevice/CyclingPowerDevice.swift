import CoreBluetooth
import Foundation

private let cyclingPowerDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.cycling-power-device")

protocol CyclingPowerDeviceDelegate: AnyObject {
    func cyclingPowerDeviceState(_ device: CyclingPowerDevice, state: CyclingPowerDeviceState)
}

enum CyclingPowerDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private let cyclingPowerMeasurementCharacteristicId = CBUUID(string: "2A63")
private let cyclingPowerVectorCharacteristicId = CBUUID(string: "2A64")
private let cyclingPowerFeatureCharacteristicId = CBUUID(string: "2A65")

class CyclingPowerDevice: NSObject {
    private var state: CyclingPowerDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var measurementCharacteristic: CBCharacteristic?
    private var vectorCharacteristic: CBCharacteristic?
    private var featureCharacteristic: CBCharacteristic?
    private var deviceId: UUID?
    weak var delegate: (any CyclingPowerDeviceDelegate)?

    func start(deviceId: UUID?) {
        logger.info("cycling-power-device: Start \(deviceId)")
        cyclingPowerDeviceDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        logger.info("cycling-power-device: Stop")
        cyclingPowerDeviceDispatchQueue.async {
            self.stopInternal()
        }
    }

    func getState() -> CyclingPowerDeviceState {
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
        measurementCharacteristic = nil
        vectorCharacteristic = nil
        featureCharacteristic = nil
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: cyclingPowerDeviceDispatchQueue)
    }

    private func setState(state: CyclingPowerDeviceState) {
        guard state != self.state else {
            return
        }
        logger.info("cycling-power-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.cyclingPowerDeviceState(self, state: state)
    }
}

extension CyclingPowerDevice: CBCentralManagerDelegate {
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
        logger.info("cycling-power-device: Found device \(peripheral.identifier)")
        guard peripheral.identifier == deviceId else {
            return
        }
        logger.info("cycling-power-device: Stop scan")
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {}

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("cycling-power-device: Discover servies")
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

extension CyclingPowerDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        logger.info("cycling-power-device: Got services \(peripheral.services)")
        if let service = peripheral.services?.first {
            logger.info("cycling-power-device: Got service \(service)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            logger.info("cycling-power-device: Characteristic UUID \(characteristic.uuid)")
            switch characteristic.uuid {
            case cyclingPowerMeasurementCharacteristicId:
                logger.info("cycling-power-device: measurementCharacteristic")
                measurementCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case cyclingPowerVectorCharacteristicId:
                logger.info("cycling-power-device: vectorCharacteristic")
                vectorCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case cyclingPowerFeatureCharacteristicId:
                logger.info("cycling-power-device: featureCharacteristic")
                featureCharacteristic = characteristic
            default:
                break
            }
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        logger.info(
            """
            cycling-power-device: Characteristic UUID \(characteristic.uuid), \
            value \(characteristic.value?.hexString())
            """
        )
    }
}
