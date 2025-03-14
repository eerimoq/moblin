import CoreBluetooth
import Foundation

private let heartRateDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.heart-rate-device")

protocol HeartRateDeviceDelegate: AnyObject {
    func heartRateDeviceState(_ device: HeartRateDevice, state: HeartRateDeviceState)
    func heartRateStatus(_ device: HeartRateDevice, heartRate: Int)
}

enum HeartRateDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private let heartRateServiceId = CBUUID(string: "180D")

let heartRateScanner = BluetoothScanner(serviceIds: [heartRateServiceId])

private let heartRateMeasurementCharacteristicId = CBUUID(string: "2A37")

private let measurementHeartRateValueFormatIndex = 0

struct HeartRateMeasurement {
    var heartRate: UInt16 = 0

    init(value: Data) throws {
        let reader = ByteArray(data: value)
        let flags = try reader.readUInt8()
        if flags.isBitSet(index: measurementHeartRateValueFormatIndex) {
            heartRate = try reader.readUInt16Le()
        } else {
            heartRate = try UInt16(reader.readUInt8())
        }
    }
}

class HeartRateDevice: NSObject {
    private var state: HeartRateDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    // periphery:ignore
    private var measurementCharacteristic: CBCharacteristic?
    private var deviceId: UUID?
    weak var delegate: (any HeartRateDeviceDelegate)?

    func start(deviceId: UUID?) {
        heartRateDeviceDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        heartRateDeviceDispatchQueue.async {
            self.stopInternal()
        }
    }

    func getState() -> HeartRateDeviceState {
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
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: heartRateDeviceDispatchQueue)
    }

    private func setState(state: HeartRateDeviceState) {
        guard state != self.state else {
            return
        }
        logger.debug("heart-rate-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.heartRateDeviceState(self, state: state)
    }
}

extension HeartRateDevice: CBCentralManagerDelegate {
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

extension HeartRateDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == heartRateServiceId }) {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case heartRateMeasurementCharacteristicId:
                measurementCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        if measurementCharacteristic != nil {
            setState(state: .connected)
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        do {
            switch characteristic.uuid {
            case heartRateMeasurementCharacteristicId:
                try handlePowerMeasurement(value: value)
            default:
                break
            }
        } catch {
            logger.info("""
            heart-rate-device: Characteristic \(characteristic.uuid), value \(value.hexString()): \
            Error \(error)
            """)
        }
    }

    private func handlePowerMeasurement(value: Data) throws {
        let measurement = try HeartRateMeasurement(value: value)
        delegate?.heartRateStatus(self, heartRate: Int(measurement.heartRate))
    }
}
