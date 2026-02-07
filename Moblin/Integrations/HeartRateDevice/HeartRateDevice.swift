import CoreBluetooth
import Foundation

private let heartRateDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.heart-rate-device")

private let rscServiceId = CBUUID(string: "1814")
private let rscMeasurementCharacteristicId = CBUUID(string: "2A53")

private let rscStrideLengthFlagIndex = 0
private let rscTotalDistanceFlagIndex = 1

private struct RscMeasurement {
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

protocol HeartRateDeviceDelegate: AnyObject {
    func heartRateDeviceState(_ device: HeartRateDevice, state: HeartRateDeviceState)
    func heartRateStatus(_ device: HeartRateDevice, heartRate: Int)
    func heartRateDeviceRunMetrics(_ device: HeartRateDevice, metrics: DeviceRunMetrics)
}

enum HeartRateDeviceState {
    case disconnected
    case discovering
    case connecting
    case connected
}

let heartRateScanner = BluetoothScanner(serviceIds: [heartRateServiceId])

class HeartRateDevice: NSObject {
    private var state: HeartRateDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var measurementCharacteristic: CBCharacteristic?
    private var rscCharacteristic: CBCharacteristic?
    private var deviceId: UUID?
    private var lastRscUpdateTime: ContinuousClock.Instant?
    private var distanceMetersFallback = 0.0
    private var usingDeviceDistance = false
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
        rscCharacteristic = nil
        lastRscUpdateTime = nil
        distanceMetersFallback = 0
        usingDeviceDistance = false
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
            if let deviceId, let connected = central.retrieveConnectedPeripherals(
                withServices: [heartRateServiceId]
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
            centralManager?.scanForPeripherals(withServices: [heartRateServiceId])
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

extension HeartRateDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        for service in peripheral.services ?? [] {
            if service.uuid == heartRateServiceId || service.uuid == rscServiceId {
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
                measurementCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case rscMeasurementCharacteristicId:
                rscCharacteristic = characteristic
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
                try handleHeartRateMeasurement(value: value)
            case rscMeasurementCharacteristicId:
                try handleRscMeasurement(value: value)
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

    private func handleHeartRateMeasurement(value: Data) throws {
        let measurement = try HeartRateMeasurement(value: value)
        delegate?.heartRateStatus(self, heartRate: Int(measurement.heartRate))
    }

    private func handleRscMeasurement(value: Data) throws {
        let measurement = try RscMeasurement(value: value)
        var paceSecondsPerMeter: Double?
        if measurement.speedMetersPerSecond > 0 {
            paceSecondsPerMeter = 1.0 / measurement.speedMetersPerSecond
        }
        var distanceMeters: Double?
        let now = ContinuousClock.now
        if let totalDistanceMeters = measurement.totalDistanceMeters {
            usingDeviceDistance = true
            distanceMeters = totalDistanceMeters
        } else if !usingDeviceDistance {
            if let lastRscUpdateTime {
                let deltaSeconds = lastRscUpdateTime.duration(to: now).seconds
                if deltaSeconds > 0 {
                    distanceMetersFallback += measurement.speedMetersPerSecond * deltaSeconds
                }
            }
            distanceMeters = distanceMetersFallback
        }
        lastRscUpdateTime = now
        let metrics = DeviceRunMetrics(
            paceSecondsPerMeter: paceSecondsPerMeter,
            cadence: measurement.cadence,
            distanceMeters: distanceMeters
        )
        delegate?.heartRateDeviceRunMetrics(self, metrics: metrics)
    }
}
