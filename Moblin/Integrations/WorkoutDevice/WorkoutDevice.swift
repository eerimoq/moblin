import CoreBluetooth
import Foundation

private let dispatchQueue = DispatchQueue(label: "com.eerimoq.workout-device")

let workoutDeviceScanner = BluetoothScanner(serviceIds: [
    workoutDeviceHeartRateServiceId,
    workoutDeviceCyclingPowerServiceId,
])

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

class WorkoutDevice: NSObject {
    private var state: WorkoutDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private let heartRate = WorkoutDeviceHeartRate()
    private let cyclingPower = WorkoutDeviceCyclingPower()
    private var deviceId: UUID?
    weak var delegate: (any WorkoutDeviceDelegate)?

    func start(deviceId: UUID?) {
        dispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        dispatchQueue.async {
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
        heartRate.reset()
        cyclingPower.reset()
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: dispatchQueue)
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

    private func isAnyCharacteristicDiscovered() -> Bool {
        if heartRate.isAnyCharacteristicDiscovered() {
            return true
        }
        if cyclingPower.isAnyCharacteristicDiscovered() {
            return true
        }
        return false
    }

    private func handleHeartRateMeasurement(value: Data) throws {
        try delegate?.workoutDeviceHeartRate(self, heartRate: heartRate.handleMeasurement(value: value))
    }

    private func handleCyclingPowerMeasurement(value: Data) throws {
        let (power, cadence) = try cyclingPower.handleMeasurement(value: value)
        delegate?.workoutDeviceCyclingPower(self, power: power, cadence: cadence)
    }

    private func handleCyclingPowerVector(value: Data) throws {
        try cyclingPower.handlePowerVector(value: value)
    }
}

extension WorkoutDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        guard let services = peripheral.services else {
            return
        }
        if let service = services.first(where: { $0.uuid == workoutDeviceHeartRateServiceId }) {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        if let service = services.first(where: { $0.uuid == workoutDeviceCyclingPowerServiceId }) {
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
            case workoutDeviceHeartRateMeasurementCharacteristicId:
                heartRate.setMeasurementCharacteristic(characteristic)
                peripheral?.setNotifyValue(true, for: characteristic)
            case workoutDeviceCyclingPowerMeasurementCharacteristicId:
                cyclingPower.setMeasurementCharacteristic(characteristic)
                peripheral?.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        if isAnyCharacteristicDiscovered() {
            setState(state: .connected)
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        do {
            switch characteristic.uuid {
            case workoutDeviceHeartRateMeasurementCharacteristicId:
                try handleHeartRateMeasurement(value: value)
            case workoutDeviceCyclingPowerMeasurementCharacteristicId:
                try handleCyclingPowerMeasurement(value: value)
            case workoutDeviceCyclingPowerVectorCharacteristicId:
                try handleCyclingPowerVector(value: value)
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
}
