import CoreBluetooth
import Foundation

private let djiTechnologyCoLtd = Data([0xAA, 0x08])

// The actual values do not matter.
private let pairTransactionId: UInt16 = 0x8092
private let stopStreamingTransactionId: UInt16 = 0xEAC8
private let preparingToLivestreamTransactionId: UInt16 = 0x8C12
private let setupWifiTransactionId: UInt16 = 0x8C19
private let startStreamingTransactionId: UInt16 = 0x8C2C

private let fff4Id = CBUUID(string: "FFF4")
private let fff5Id = CBUUID(string: "FFF5")

private let pairPinCode = "mbln"

private enum State {
    case idle
    case discovering
    case connecting
    case checkingIfPaired
    case pairing
    case stoppingStream
    case preparingStream
    case settingUpWifi
    case startingStream
    case streaming
}

class DjiController: NSObject {
    private let wifiSsid: String
    private let wifiPassword: String
    private let rtmpUrl: String
    private var centralManager: CBCentralManager?
    private var cameraPeripheral: CBPeripheral?
    private var fff5Characteristic: CBCharacteristic?
    private var state: State = .idle

    init(wifiSsid: String, wifiPassword: String, rtmpUrl: String) {
        self.wifiSsid = wifiSsid
        self.wifiPassword = wifiPassword
        self.rtmpUrl = rtmpUrl
    }

    func start() {
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    private func setState(state: State) {
        logger.info("dji-controller: State change \(self.state) -> \(state)")
        self.state = state
    }
}

extension DjiController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager?.scanForPeripherals(withServices: nil)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi _: NSNumber)
    {
        guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData else {
            return
        }
        guard Data(bytes: data.bytes, count: min(2, data.count)) == djiTechnologyCoLtd else {
            return
        }
        central.stopScan()
        cameraPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {}

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {}
}

extension DjiController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        guard let peripheralServices = peripheral.services else {
            return
        }
        for service in peripheralServices {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == fff5Id {
                fff5Characteristic = characteristic
            }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        guard let message = try? DjiMessage(data: value) else {
            logger.info("dji-controller: Discarding corrupt message \(value.hexString())")
            return
        }
        switch state {
        case .checkingIfPaired:
            processCheckingIfPaired(response: message)
        case .pairing:
            processPairing()
        case .stoppingStream:
            processStoppingStream(response: message)
        case .preparingStream:
            processPreparingStream(response: message)
        case .settingUpWifi:
            processSettingUpWifi(response: message)
        case .startingStream:
            processStartingStream(response: message)
        case .streaming:
            break
        default:
            logger.info("dji-controller: Received message in unexpected state '\(state)'")
        }
    }

    private func stopStream() {
        writeMessage(message: DjiMessage(target: 0x0802,
                                         id: stopStreamingTransactionId,
                                         type: 0x8E0240,
                                         payload: Data([0x01, 0x01, 0x1A, 0x00, 0x01, 0x02])))
        setState(state: .stoppingStream)
    }

    private func processCheckingIfPaired(response: DjiMessage) {
        guard response.id == pairTransactionId else {
            return
        }
        if response.payload == Data([0, 1]) {
            stopStream()
        } else {
            setState(state: .pairing)
        }
    }

    private func processPairing() {
        stopStream()
    }

    private func processStoppingStream(response: DjiMessage) {
        guard response.id == stopStreamingTransactionId else {
            return
        }
        writeMessage(message: DjiMessage(target: 0x0802,
                                         id: preparingToLivestreamTransactionId,
                                         type: 0xE10240,
                                         payload: Data([0x1A])))
        setState(state: .preparingStream)
    }

    private func processPreparingStream(response: DjiMessage) {
        guard response.id == preparingToLivestreamTransactionId else {
            return
        }
        let payload = djiPackString(value: wifiSsid) + djiPackString(value: wifiPassword)
        writeMessage(message: DjiMessage(target: 0x0702,
                                         id: setupWifiTransactionId,
                                         type: 0x470740,
                                         payload: payload))
        setState(state: .settingUpWifi)
    }

    private func processSettingUpWifi(response: DjiMessage) {
        guard response.id == setupWifiTransactionId else {
            return
        }
        var payload = Data([0x00, 0x2E, 0x00, 0x0A, 0xB8, 0x0B, 0x02, 0x00,
                            0x00, 0x00, 0x00, 0x00])
        payload += djiPackUrl(url: rtmpUrl)
        writeMessage(message: DjiMessage(target: 0x0802,
                                         id: startStreamingTransactionId,
                                         type: 0x780840,
                                         payload: payload))
        setState(state: .startingStream)
    }

    private func processStartingStream(response: DjiMessage) {
        guard response.id == startStreamingTransactionId else {
            return
        }
        setState(state: .streaming)
    }

    private func writeMessage(message: DjiMessage) {
        writeValue(value: message.encode())
    }

    private func writeValue(value: Data) {
        guard let fff5Characteristic else {
            return
        }
        cameraPeripheral?.writeValue(value, for: fff5Characteristic, type: .withoutResponse)
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error _: Error?
    ) {
        guard characteristic.uuid == fff4Id else {
            return
        }
        var payload = Data([
            0x20, 0x32, 0x38, 0x34, 0x61, 0x65, 0x35, 0x62,
            0x38, 0x64, 0x37, 0x36, 0x62, 0x33, 0x33, 0x37,
            0x35, 0x61, 0x30, 0x34, 0x61, 0x36, 0x34, 0x31,
            0x37, 0x61, 0x64, 0x37, 0x31, 0x62, 0x65, 0x61,
            0x33,
        ])
        payload += djiPackString(value: pairPinCode)
        let request = DjiMessage(target: 0x0702, id: pairTransactionId, type: 0x450740, payload: payload)
        writeMessage(message: request)
        setState(state: .checkingIfPaired)
    }

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {}
}
