import CoreBluetooth
import Foundation

private let cyclingPowerDeviceDispatchQueue = DispatchQueue(label: "com.eerimoq.cycling-power-device")

protocol CyclingPowerDeviceDelegate: AnyObject {
    func cyclingPowerDeviceState(_ device: CyclingPowerDevice, state: CyclingPowerDeviceState)
    func cyclingPowerStatus(_ device: CyclingPowerDevice, power: Int, cadence: Double)
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

private let measurementPedalPowerBalanceFlagIndex = 0
// periphery:ignore
private let measurementPedalPowerBalanceReferenceIndex = 1
private let measurementAccumulatedTorqueFlagIndex = 2
// periphery:ignore
private let measurementAccumulatedTorqueSourceIndex = 3
private let measurementWheelRevolutionDataFlagIndex = 4
private let measurementCrankRevolutionDataFlagIndex = 5
private let measurementExtremeForceFlagIndex = 6
private let measurementExtremeTorqueFlagIndex = 7
private let measurementExtremeAnglesFlagIndex = 8
private let measurementTopDeadSpotAngleFlagIndex = 9
private let measurementBottomDeadSpotAngleFlagIndex = 10
private let measurementAccumulatedEnergyFlagIndex = 11
// periphery:ignore
private let measurementOffsetCompensationIndicatorFlagIndex = 12

enum CyclingPowerPedalPowerBalanceReference: UInt8 {
    case unknown = 0
    case left = 1
}

enum CyclingPowerAccumulatedTorqueSource: UInt8 {
    case wheelBased = 0
    case crackBased = 1
}

struct CyclingPowerMeasurement {
    // periphery:ignore
    var instantaneousPower: UInt16 = 0
    // periphery:ignore
    var pedalPowerBalance: UInt8?
    // periphery:ignore
    var pedalPowerBalanceReference: CyclingPowerPedalPowerBalanceReference?
    // periphery:ignore
    var accumulatedTorque: UInt16?
    // periphery:ignore
    var accumulatedTorqueSource: CyclingPowerAccumulatedTorqueSource?
    // periphery:ignore
    var cumulativeWheelRevolutions: UInt32?
    // periphery:ignore
    var lastWheelEventTime: UInt16?
    // periphery:ignore
    var cumulativeCrankRevolutions: UInt16?
    // periphery:ignore
    var lastCrankEventTime: UInt16?
    // periphery:ignore
    var maximumForceMagnitude: UInt16?
    // periphery:ignore
    var minimumForceMagnitude: UInt16?
    // periphery:ignore
    var maximumTorqueMagnitude: UInt16?
    // periphery:ignore
    var minimumTorqueMagnitude: UInt16?
    // periphery:ignore
    var extremeAngles: UInt16?
    // periphery:ignore
    var topDeadSpotAngle: UInt16?
    // periphery:ignore
    var bottomDeadSpotAngle: UInt16?
    // periphery:ignore
    var accumulatedEnergy: UInt16?
}

private let vectorCrankRevolutionDataFlagIndex = 0
private let vectorFirstCrankMeasurementAngleFlagIndex = 1
private let vectorInstantaneousForceArrayFlagIndex = 2
private let vectorInstantaneousTorqueArrayFlagIndex = 3
private let vectorInstantaneousMeasurementDirectionMask: UInt8 = 0b110000
private let vectorInstantaneousMeasurementDirectionIndex = 4

enum CyclingPowerInstantaneousMeasurementDirection: UInt8 {
    case unknown = 0
    case tangentialComponent = 1
    case radialComponent = 2
    case lateralComponent = 3
}

struct CyclingPowerVector {
    // periphery:ignore
    var cumulativeCrankRevolutions: UInt16?
    // periphery:ignore
    var lastCrankEventTime: UInt16?
    // periphery:ignore
    var firstCrankMeasurementAngle: UInt16?
    // periphery:ignore
    var instantaneousForceMagnitudes: [UInt16]?
    // periphery:ignore
    var instantaneousTorqueMagnitudes: [UInt16]?
    // periphery:ignore
    var instantaneousMeasurementDirection: CyclingPowerInstantaneousMeasurementDirection?
}

class CyclingPowerDevice: NSObject {
    private var state: CyclingPowerDeviceState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    // periphery:ignore
    private var measurementCharacteristic: CBCharacteristic?
    // periphery:ignore
    private var vectorCharacteristic: CBCharacteristic?
    // periphery:ignore
    private var featureCharacteristic: CBCharacteristic?
    private var deviceId: UUID?
    weak var delegate: (any CyclingPowerDeviceDelegate)?
    private var previousRevolutions: UInt16?
    private var previousRevolutionsTime: ContinuousClock.Instant?

    func start(deviceId: UUID?) {
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
        previousRevolutions = nil
        previousRevolutionsTime = nil
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
        logger.info("cycling-power-device: Got services \(peripheral.services ?? [])")
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
                measurementCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case cyclingPowerVectorCharacteristicId:
                vectorCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case cyclingPowerFeatureCharacteristicId:
                featureCharacteristic = characteristic
            default:
                break
            }
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        do {
            switch characteristic.uuid {
            case cyclingPowerMeasurementCharacteristicId:
                try handlePowerMeasurement(value: value)
            case cyclingPowerVectorCharacteristicId:
                try handlePowerVector(value: value)
            default:
                break
            }
        } catch {
            logger.info("""
            cycling-power-device: Characteristic \(characteristic.uuid), value \(value.hexString()): \
            Error \(error)
            """)
        }
    }

    private func handlePowerMeasurement(value: Data) throws {
        var measurement = CyclingPowerMeasurement()
        let reader = ByteArray(data: value)
        let flags = try reader.readUInt16Le()
        measurement.instantaneousPower = try reader.readUInt16Le()
        if flags.isBitSet(index: measurementPedalPowerBalanceFlagIndex) {
            measurement.pedalPowerBalance = try reader.readUInt8()
        }
        if flags.isBitSet(index: measurementAccumulatedTorqueFlagIndex) {
            measurement.accumulatedTorque = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementWheelRevolutionDataFlagIndex) {
            measurement.cumulativeWheelRevolutions = try reader.readUInt32Le()
            measurement.lastWheelEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementCrankRevolutionDataFlagIndex) {
            measurement.cumulativeCrankRevolutions = try reader.readUInt16Le()
            measurement.lastCrankEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementExtremeForceFlagIndex) {
            measurement.maximumForceMagnitude = try reader.readUInt16Le()
            measurement.minimumForceMagnitude = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementExtremeTorqueFlagIndex) {
            measurement.maximumTorqueMagnitude = try reader.readUInt16Le()
            measurement.minimumTorqueMagnitude = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementExtremeAnglesFlagIndex) {
            _ = try reader.readBytes(3)
        }
        if flags.isBitSet(index: measurementTopDeadSpotAngleFlagIndex) {
            measurement.topDeadSpotAngle = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementBottomDeadSpotAngleFlagIndex) {
            measurement.bottomDeadSpotAngle = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementAccumulatedEnergyFlagIndex) {
            measurement.accumulatedEnergy = try reader.readUInt16Le()
        }
        // logger.info("cycling-power-device: \(measurement)")
        var cadence = 0.0
        if let revolutions = measurement.cumulativeCrankRevolutions {
            let now = ContinuousClock.now
            if let previousRevolutions, let previousRevolutionsTime {
                var deltaRevolutions: UInt16 = 0
                if revolutions >= previousRevolutions {
                    deltaRevolutions = revolutions - previousRevolutions
                } else {
                    deltaRevolutions = revolutions + (UInt16.max - previousRevolutions + 1)
                }
                cadence = 60 * Double(deltaRevolutions) / previousRevolutionsTime.duration(to: now).seconds
            }
            previousRevolutions = revolutions
            previousRevolutionsTime = now
        }
        delegate?.cyclingPowerStatus(self, power: Int(measurement.instantaneousPower), cadence: cadence)
    }

    private func handlePowerVector(value: Data) throws {
        var vector = CyclingPowerVector()
        let reader = ByteArray(data: value)
        let flags = try reader.readUInt8()
        if flags.isBitSet(index: vectorCrankRevolutionDataFlagIndex) {
            vector.cumulativeCrankRevolutions = try reader.readUInt16Le()
            vector.lastCrankEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: vectorFirstCrankMeasurementAngleFlagIndex) {
            vector.firstCrankMeasurementAngle = try reader.readUInt16Le()
        }
        while reader.bytesAvailable >= 2 {
            let value = try reader.readUInt16Le()
            if flags.isBitSet(index: vectorInstantaneousForceArrayFlagIndex) {
                if vector.instantaneousForceMagnitudes == nil {
                    vector.instantaneousForceMagnitudes = []
                }
                vector.instantaneousForceMagnitudes!.append(value)
            } else if flags.isBitSet(index: vectorInstantaneousTorqueArrayFlagIndex) {
                if vector.instantaneousTorqueMagnitudes == nil {
                    vector.instantaneousTorqueMagnitudes = []
                }
                vector.instantaneousTorqueMagnitudes!.append(value)
            }
        }
        let value = (flags & vectorInstantaneousMeasurementDirectionMask) >>
            vectorInstantaneousMeasurementDirectionIndex
        vector.instantaneousMeasurementDirection = CyclingPowerInstantaneousMeasurementDirection(rawValue: value)
        // logger.info("cycling-power-device: \(vector)")
    }
}
