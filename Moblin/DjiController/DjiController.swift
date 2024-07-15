import CoreBluetooth
import Foundation

private let djiOsmoAction4ManufacturerData = Data([
    0xAA, 0x08, 0x14, 0x00, 0xFA, 0xE4, 0x7A, 0x2C,
    0x13, 0x04, 0x2D,
])

private let pairId: UInt16 = 0x8092
private let preparingToLivestreamId: UInt16 = 0x8C12
private let setupWifiId: UInt16 = 0x8C19
private let startStreamingId: UInt16 = 0x8C2C

private let fff4Id = CBUUID(string: "FFF4")
private let fff5Id = CBUUID(string: "FFF5")

private let pairPinCode = "1234"

private enum State {
    case idle
    case discovering
    case connecting
    case checkingIfPaired
    case pairing
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
        guard Data(bytes: data.bytes, count: data.count) == djiOsmoAction4ManufacturerData else {
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
            return
        }
        switch state {
        case .checkingIfPaired:
            handlePairResponse(response: message)
        case .pairing:
            prepareToLivestream()
        case .preparingStream:
            handlePreparingToLivestreamResponse(response: message)
        case .settingUpWifi:
            handleSetupWifiResponse(response: message)
        case .startingStream:
            handleStartStreamingResponse(response: message)
        case .streaming:
            break
        default:
            logger.info("dji-controller: Received message in unexpected state '\(state)'")
        }
    }

    private func prepareToLivestream() {
        writeMessage(message: DjiMessage(target: 0x080266,
                                         id: preparingToLivestreamId,
                                         type: 0xE10240,
                                         payload: Data([0x1A])))
        setState(state: .preparingStream)
    }

    private func handlePairResponse(response: DjiMessage) {
        guard response.id == pairId else {
            return
        }
        if response.payload == Data([0, 1]) {
            prepareToLivestream()
        } else {
            setState(state: .pairing)
        }
    }

    private func handlePreparingToLivestreamResponse(response: DjiMessage) {
        guard response.id == preparingToLivestreamId else {
            return
        }
        let payload = djiPackString(value: wifiSsid) + djiPackString(value: wifiPassword)
        writeMessage(message: DjiMessage(target: 0x07021B,
                                         id: setupWifiId,
                                         type: 0x470740,
                                         payload: payload))
        setState(state: .settingUpWifi)
    }

    private func handleSetupWifiResponse(response: DjiMessage) {
        guard response.id == setupWifiId else {
            return
        }
        var payload = Data([0x00, 0x2E, 0x00, 0x0A, 0xB8, 0x0B, 0x02, 0x00,
                            0x00, 0x00, 0x00, 0x00])
        payload += djiPackUrl(url: rtmpUrl)
        writeMessage(message: DjiMessage(target: 0x08024B,
                                         id: startStreamingId,
                                         type: 0x780840,
                                         payload: payload))
        setState(state: .startingStream)
    }

    private func handleStartStreamingResponse(response: DjiMessage) {
        guard response.id == startStreamingId else {
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
        let request = DjiMessage(target: 0x0702C2, id: pairId, type: 0x450740, payload: payload)
        writeMessage(message: request)
        setState(state: .checkingIfPaired)
    }

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {}
}
