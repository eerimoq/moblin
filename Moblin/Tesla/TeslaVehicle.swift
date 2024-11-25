import CoreBluetooth
import CryptorECC
import Telegraph

private let vehicleServiceUuid = CBUUID(string: "00000211-b2d1-43f0-9b88-960cebf8b91e")
private let toVehicleUuid = CBUUID(string: "00000212-b2d1-43f0-9b88-960cebf8b91e")
private let fromVehicleUuid = CBUUID(string: "00000213-b2d1-43f0-9b88-960cebf8b91e")

class TeslaVehicle: NSObject {
    private let vin: String
    private let privateKey: ECPrivateKey
    private let publicKey: ECPublicKey
    private var centralManager: CBCentralManager?
    private var vehiclePeripheral: CBPeripheral?
    private var toVehicleCharacteristic: CBCharacteristic?
    private var fromVehicleCharacteristic: CBCharacteristic?

    init?(vin: String, privateKey: String) {
        self.vin = vin
        do {
            self.privateKey = try ECPrivateKey(key: privateKey)
            publicKey = try self.privateKey.extractPublicKey()
        } catch {
            logger.error("tesla-vehicle: Error \(error)")
            return nil
        }
    }

    func start() {
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stop() {
        centralManager = nil
    }

    private func localName() -> String {
        let hash = SHA1.hash(vin.utf8Data).prefix(8).hexString()
        return "S\(hash)C"
    }
}

extension TeslaVehicle: CBCentralManagerDelegate {
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
        guard let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return
        }
        guard localName == self.localName() else {
            return
        }
        logger.info("tesla-vehicle: Connecting to \(localName)")
        central.stopScan()
        vehiclePeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {
        logger.info("tesla-vehicle: Connect failure")
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("tesla-vehicle: Connected")
        peripheral.discoverServices([vehicleServiceUuid])
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
        logger.info("tesla-vehicle: Disconnected")
    }
}

extension TeslaVehicle: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        logger.info("tesla-vehicle: Peripheral didDiscoverServices")
        guard let peripheralServices = peripheral.services else {
            logger.info("tesla-vehicle: No services found")
            return
        }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([toVehicleUuid, fromVehicleUuid], for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        logger.info("tesla-vehicle: Peripheral didDiscoverCharacteristicsFor")
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == toVehicleUuid {
                logger.info("tesla-vehicle: Found to vehicle characteristic")
                toVehicleCharacteristic = characteristic
            } else if characteristic.uuid == fromVehicleUuid {
                logger.info("tesla-vehicle: Found from vehicle characteristic")
                fromVehicleCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                logger.info("tesla-vehicle: Found unknown characteristic \(characteristic.uuid)")
            }
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor _: CBCharacteristic, error _: Error?) {
        logger.info("tesla-vehicle: Peripheral didUpdateValueFor")
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateNotificationStateFor _: CBCharacteristic,
        error _: Error?
    ) {
        logger.info("tesla-vehicle: Peripheral didUpdateNotificationStateFor")
    }

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {
        logger.info("tesla-vehicle: Peripheral peripheralIsReady toSendWriteWithoutResponse")
    }
}
