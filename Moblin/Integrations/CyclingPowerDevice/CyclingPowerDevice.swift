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

private let measurementPedalPowerBalanceFlagIndex = 0
private let measurementAccumulatedTorqueFlagIndex = 2
private let measurementWheelRevFlagIndex = 4
private let measurementCrankRevFlagIndex = 5
private let measurementExtremeForceFlagIndex = 6
private let measurementExtremeTorqueFlagIndex = 7
private let measurementExtremeAnglesFlagIndex = 8
private let measurementTopDeadSpotAngleFlagIndex = 9
private let measurementBottomDeadSpotAngleFlagIndex = 10
private let measurementAccumulatedEnergyFlagIndex = 11

struct CyclingPowerMeasurement {
    // periphery:ignore
    var instantaneousPower: UInt16 = 0
    // periphery:ignore
    var pedalPowerBalance: UInt8 = 0
    // periphery:ignore
    var accumulatedTorque: UInt16 = 0
    // periphery:ignore
    var cumulativeWheelRevs: UInt32 = 0
    // periphery:ignore
    var lastWheelEventTime: UInt16 = 0
    // periphery:ignore
    var cumulativeCrankRevs: UInt16 = 0
    // periphery:ignore
    var lastCrankEventTime: UInt16 = 0
    // periphery:ignore
    var maximumForceMagnitude: UInt16 = 0
    // periphery:ignore
    var minimumForceMagnitude: UInt16 = 0
    // periphery:ignore
    var maximumTorqueMagnitude: UInt16 = 0
    // periphery:ignore
    var minimumTorqueMagnitude: UInt16 = 0
    // periphery:ignore
    var extremeAngles: UInt16 = 0
    // periphery:ignore
    var topDeadSpotAngle: UInt16 = 0
    // periphery:ignore
    var bottomDeadSpotAngle: UInt16 = 0
    // periphery:ignore
    var accumulatedEnergy: UInt16 = 0
}

private let vectorCrankRevolutionsFlagIndex = 0
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
    var cumulativeCrankRevs: UInt16 = 0
    // periphery:ignore
    var lastCrankEventTime: UInt16 = 0
    // periphery:ignore
    var firstCrankMeasurementAngle: UInt16 = 0
    // periphery:ignore
    var instantaneousMeasurementDirection: CyclingPowerInstantaneousMeasurementDirection = .unknown
    // periphery:ignore
    var instantaneousForces: [UInt16] = []
    // periphery:ignore
    var instantaneousTorques: [UInt16] = []
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
                logger.info("""
                cycling-power-device: Characteristic \(characteristic.uuid), value \(value.hexString())
                """)
            }
        } catch {
            logger.info("""
            cycling-power-device: Characteristic \(characteristic.uuid), value \(value.hexString()): Error \(error)
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
        if flags.isBitSet(index: measurementWheelRevFlagIndex) {
            measurement.cumulativeWheelRevs = try reader.readUInt32Le()
            measurement.lastWheelEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementCrankRevFlagIndex) {
            measurement.cumulativeCrankRevs = try reader.readUInt16Le()
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
        logger.info("cycling-power-device: Measurement \(measurement)")
    }

    private func handlePowerVector(value: Data) throws {
        var vector = CyclingPowerVector()
        let reader = ByteArray(data: value)
        let flags = try reader.readUInt8()
        vector
            .instantaneousMeasurementDirection =
            CyclingPowerInstantaneousMeasurementDirection(rawValue: (flags &
                    vectorInstantaneousMeasurementDirectionMask) >> vectorInstantaneousMeasurementDirectionIndex) ??
            .unknown
        if flags.isBitSet(index: vectorCrankRevolutionsFlagIndex) {
            vector.cumulativeCrankRevs = try reader.readUInt16Le()
            vector.lastCrankEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: vectorFirstCrankMeasurementAngleFlagIndex) {
            vector.firstCrankMeasurementAngle = try reader.readUInt16Le()
        }
        while reader.bytesAvailable >= 2 {
            let value = try reader.readUInt16Le()
            if flags.isBitSet(index: vectorInstantaneousForceArrayFlagIndex) {
                vector.instantaneousForces.append(value)
            } else if flags.isBitSet(index: vectorInstantaneousTorqueArrayFlagIndex) {
                vector.instantaneousTorques.append(value)
            }
        }
        logger.info("cycling-power-device: Vector \(vector)")
    }
}
