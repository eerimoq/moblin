import CoreBluetooth
import CryptorECC
import Telegraph

private let vehicleServiceUuid = CBUUID(string: "00000211-b2d1-43f0-9b88-960cebf8b91e")
private let toVehicleUuid = CBUUID(string: "00000212-b2d1-43f0-9b88-960cebf8b91e")
private let fromVehicleUuid = CBUUID(string: "00000213-b2d1-43f0-9b88-960cebf8b91e")

enum TeslaVehicleState {
    case idle
    case discovering
    case connecting
    case handshaking
}

class TeslaVehicle: NSObject {
    private let vin: String
    private let privateKey: ECPrivateKey
    private let publicKey: ECPublicKey
    private var centralManager: CBCentralManager?
    private var vehiclePeripheral: CBPeripheral?
    private var toVehicleCharacteristic: CBCharacteristic?
    private var fromVehicleCharacteristic: CBCharacteristic?
    private var state: TeslaVehicleState = .idle
    private var responseHandlers: [Data: (UniversalMessage_RoutableMessage) -> Void] = [:]

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
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stop() {
        centralManager = nil
    }

    private func setState(state: TeslaVehicleState) {
        guard state != self.state else {
            return
        }
        logger.info("tesla-vehicle: State change \(self.state) -> \(state)")
        self.state = state
    }

    private func localName() -> String {
        let hash = SHA1.hash(vin.utf8Data).prefix(8).hexString()
        return "S\(hash)C"
    }

    private func getNextAddress() -> Data {
        return Data.random(length: 16)
    }

    private func startHandshake() {
        setState(state: .handshaking)
        sendSessionInfoRequest(domain: .vehicleSecurity)
        sendSessionInfoRequest(domain: .infotainment)
    }

    private func sendSessionInfoRequest(domain: UniversalMessage_Domain) {
        let address = getNextAddress()
        let uuid = Data.random(length: 16)
        var message = UniversalMessage_RoutableMessage()
        message.toDestination.subDestination = .domain(domain)
        message.fromDestination.subDestination = .routingAddress(address)
        message.sessionInfoRequest.publicKey = privateKey.pubKeyBytes
        message.uuid = uuid
        responseHandlers[address] = handleSessionInfoResponse(message:)
        sendMessage(message: message)
    }

    private func handleSessionInfoResponse(message: UniversalMessage_RoutableMessage) {
        logger.info("tesla-vehicle: Got \(message.signedMessageStatus.signedMessageFault)")
        logger.info("tesla-vehicle: Got session info for \(message.toDestination)")
    }

    private func handleMessage(message: Data) {
        logger.info("tesla-vehicle: Got \(message.hexString())")
        guard let message = try? UniversalMessage_RoutableMessage(serializedBytes: message) else {
            logger.info("tesla-vehicle: Discarding corrupt message \(message.hexString())")
            return
        }
        logger.info("tesla-vehicle: Got \(message)")
        switch message.toDestination.subDestination {
        case let .routingAddress(address):
            logger.info("tesla-vehicle: Address \(address)")
            responseHandlers[address]?(message)
        default:
            logger.info("tesla-vehicle: Unexpected non-routing address destination.")
        }
    }

    private func sendMessage(message: UniversalMessage_RoutableMessage) {
        guard let message = try? message.serializedData(), let toVehicleCharacteristic else {
            return
        }
        logger.info("tesla-vehicle: Sending \(message.hexString())")
        let writer = ByteArray()
        writer.writeUInt16(UInt16(message.count))
        writer.writeBytes(message)
        let data = writer.data
        let blockLength = 20
        for offset in stride(from: 0, to: data.count, by: blockLength) {
            let block = data[offset ..< min(offset + blockLength, data.count)]
            logger.info("tesla-vehicle: Sending block \(block.hexString())")
            vehiclePeripheral?.writeValue(block, for: toVehicleCharacteristic, type: .withoutResponse)
        }
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

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
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
        setState(state: .connecting)
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
        guard let peripheralServices = peripheral.services else {
            logger.error("tesla-vehicle: No services found")
            return
        }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([toVehicleUuid, fromVehicleUuid], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error _: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == toVehicleUuid {
                toVehicleCharacteristic = characteristic
            } else if characteristic.uuid == fromVehicleUuid {
                fromVehicleCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                logger.error("tesla-vehicle: Found unknown characteristic \(characteristic.uuid)")
            }
        }
        startHandshake()
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        handleMessage(message: value)
    }

    func peripheral(_: CBPeripheral, didUpdateNotificationStateFor _: CBCharacteristic, error _: Error?) {}

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {}
}
