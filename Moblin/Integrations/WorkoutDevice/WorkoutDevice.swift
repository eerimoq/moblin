import Collections
import CoreBluetooth
import Foundation

private let workoutDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.workout-device")

protocol WorkoutDeviceDelegate: AnyObject {
    func workoutDeviceState(_ device: WorkoutDevice, state: WorkoutDeviceState)
    func workoutDeviceHeartRate(_ device: WorkoutDevice, heartRate: Int)
    func workoutDeviceCyclingPower(_ device: WorkoutDevice, power: Int, cadence: Int)
}

enum WorkoutDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

let workoutScanner = BluetoothScanner(serviceIds: [heartRateServiceId, cyclingPowerServiceId])

class WorkoutDevice: NSObject {
    private var state: WorkoutDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var heartRateMeasurementCharacteristic: CBCharacteristic?
    private var cyclingPowerMeasurementCharacteristic: CBCharacteristic?
    private var deviceId: UUID?
    weak var delegate: (any WorkoutDeviceDelegate)?
    
    // Cycling power specific state
    private var cyclingPowerState = CyclingPowerState()

    func start(deviceId: UUID?) {
        workoutDeviceDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        workoutDeviceDispatchQueue.async {
            self.stopInternal()
        }
    }

    func getState() -> WorkoutDeviceState {
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
        heartRateMeasurementCharacteristic = nil
        cyclingPowerMeasurementCharacteristic = nil
        cyclingPowerState.reset()
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: workoutDeviceDispatchQueue)
    }

    private func setState(state: WorkoutDeviceState) {
        guard state != self.state else {
            return
        }
        logger.debug("workout-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.workoutDeviceState(self, state: state)
    }
}

extension WorkoutDevice: CBCentralManagerDelegate {
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

extension WorkoutDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        // Look for both heart rate and cycling power services
        for service in peripheral.services ?? [] {
            if service.uuid == heartRateServiceId || service.uuid == cyclingPowerServiceId {
                peripheral.discoverCharacteristics(nil, for: service)
            }
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
                heartRateMeasurementCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case cyclingPowerMeasurementCharacteristicId:
                cyclingPowerMeasurementCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        if heartRateMeasurementCharacteristic != nil || cyclingPowerMeasurementCharacteristic != nil {
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
                try handleHeartRateMeasurement(value: value)
            case cyclingPowerMeasurementCharacteristicId:
                try handleCyclingPowerMeasurement(value: value)
            case vectorCharacteristicId:
                try handlePowerVector(value: value)
            default:
                break
            }
        } catch {
            logger.info("""
            workout-device: Characteristic \(characteristic.uuid), value \(value.hexString()): \
            Error \(error)
            """)
        }
    }

    private func handleHeartRateMeasurement(value: Data) throws {
        let measurement = try HeartRateMeasurement(value: value)
        delegate?.workoutDeviceHeartRate(self, heartRate: Int(measurement.heartRate))
    }

    private func handleCyclingPowerMeasurement(value: Data) throws {
        let measurement = try CyclingPowerMeasurement(value: value)
        let result = cyclingPowerState.processMeasurement(measurement)
        delegate?.workoutDeviceCyclingPower(self, power: result.power, cadence: result.cadence)
    }

    private func handlePowerVector(value: Data) throws {
        _ = try CyclingPowerVector(value: value)
    }
}
