import CoreBluetooth
import Foundation

private let garminDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.garmin-device")

protocol GarminDeviceDelegate: AnyObject {
    func garminDeviceState(_ device: GarminDevice, state: GarminDeviceState)
    func garminMetrics(_ device: GarminDevice, metrics: GarminMetrics)
}

enum GarminDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

struct GarminMetrics {
    var heartRate: Int?
    var speedMetersPerSecond: Double?
    var cadence: Int?
    var distanceMeters: Double?
    var timestamp: ContinuousClock.Instant = .now
}

private let garminRscServiceId = CBUUID(string: "1814")
private let garminRscMeasurementCharacteristicId = CBUUID(string: "2A53")

let garminScanner = BluetoothScanner(serviceIds: [
    heartRateServiceId,
    garminRscServiceId,
])

private let rscStrideLengthFlagIndex = 0
private let rscTotalDistanceFlagIndex = 1

private struct GarminRscMeasurement {
    var speedMetersPerSecond: Double
    var cadence: Int
    var totalDistanceMeters: Double?

    init(value: Data) throws {
        let reader = ByteReader(data: value)
        let flags = try reader.readUInt8()
        let speedRaw = try reader.readUInt16Le()
        speedMetersPerSecond = Double(speedRaw) / 256.0
        cadence = Int(try reader.readUInt8())
        if flags.isBitSet(index: rscStrideLengthFlagIndex) {
            _ = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: rscTotalDistanceFlagIndex) {
            let totalDistanceRaw = try reader.readUInt32Le()
            totalDistanceMeters = Double(totalDistanceRaw) / 10.0
        }
    }
}

class GarminDevice: NSObject {
    private var state: GarminDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    private var rscCharacteristic: CBCharacteristic?
    private var deviceId: UUID?
    private var metrics = GarminMetrics()
    private var lastRscUpdateTime: ContinuousClock.Instant?
    private var distanceMetersFallback = 0.0
    private var usingDeviceDistance = false
    weak var delegate: (any GarminDeviceDelegate)?

    func start(deviceId: UUID?) {
        garminDeviceDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        garminDeviceDispatchQueue.async {
            self.stopInternal()
        }
    }

    func getState() -> GarminDeviceState {
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
        heartRateCharacteristic = nil
        rscCharacteristic = nil
        lastRscUpdateTime = nil
        distanceMetersFallback = 0
        usingDeviceDistance = false
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: garminDeviceDispatchQueue)
    }

    private func setState(state: GarminDeviceState) {
        guard state != self.state else {
            return
        }
        logger.debug("garmin-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.garminDeviceState(self, state: state)
    }

    private func notifyMetricsUpdated() {
        metrics.timestamp = .now
        delegate?.garminMetrics(self, metrics: metrics)
    }
}

extension GarminDevice: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if let deviceId, let connected = central.retrieveConnectedPeripherals(
                withServices: [heartRateServiceId, garminRscServiceId]
            ).first(where: { $0.identifier == deviceId }) {
                connectToPeripheral(central: central, peripheral: connected)
                return
            }
            if let deviceId, let cached = central.retrievePeripherals(
                withIdentifiers: [deviceId]
            ).first {
                connectToPeripheral(central: central, peripheral: cached)
                return
            }
            centralManager?.scanForPeripherals(
                withServices: [heartRateServiceId, garminRscServiceId]
            )
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
        connectToPeripheral(central: central, peripheral: peripheral)
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

    private func connectToPeripheral(central: CBCentralManager, peripheral: CBPeripheral) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        setState(state: .connecting)
        if peripheral.state == .connected {
            peripheral.discoverServices(nil)
        } else {
            central.connect(peripheral, options: nil)
        }
    }
}

extension GarminDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        for service in peripheral.services ?? [] {
            if service.uuid == heartRateServiceId
                || service.uuid == garminRscServiceId
            {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case heartRateMeasurementCharacteristicId:
                heartRateCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case garminRscMeasurementCharacteristicId:
                rscCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        if heartRateCharacteristic != nil || rscCharacteristic != nil {
            setState(state: .connected)
        }
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error _: Error?
    ) {
        guard let value = characteristic.value else {
            return
        }
        do {
            switch characteristic.uuid {
            case heartRateMeasurementCharacteristicId:
                try handleHeartRateMeasurement(value: value)
            case garminRscMeasurementCharacteristicId:
                try handleRscMeasurement(value: value)
            default:
                break
            }
        } catch {
            logger.info("""
            garmin-device: Characteristic \(characteristic.uuid), value \(value.hexString()): \
            Error \(error)
            """)
        }
    }

    private func handleHeartRateMeasurement(value: Data) throws {
        let measurement = try HeartRateMeasurement(value: value)
        metrics.heartRate = Int(measurement.heartRate)
        notifyMetricsUpdated()
    }

    private func handleRscMeasurement(value: Data) throws {
        let measurement = try GarminRscMeasurement(value: value)
        metrics.speedMetersPerSecond = measurement.speedMetersPerSecond
        metrics.cadence = measurement.cadence
        let now = ContinuousClock.now
        if let totalDistanceMeters = measurement.totalDistanceMeters {
            usingDeviceDistance = true
            metrics.distanceMeters = totalDistanceMeters
        } else if !usingDeviceDistance {
            if let lastRscUpdateTime {
                let deltaSeconds = lastRscUpdateTime.duration(to: now).seconds
                if deltaSeconds > 0 {
                    distanceMetersFallback += measurement.speedMetersPerSecond * deltaSeconds
                }
            }
            metrics.distanceMeters = distanceMetersFallback
        }
        lastRscUpdateTime = now
        notifyMetricsUpdated()
    }

}
