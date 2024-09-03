import CoreBluetooth
import Foundation

// The actual values do not matter.
private let pairTransactionId: UInt16 = 0x8092
private let stopStreamingTransactionId: UInt16 = 0xEAC8
private let preparingToLivestreamTransactionId: UInt16 = 0x8C12
private let setupWifiTransactionId: UInt16 = 0x8C19
private let startStreamingTransactionId: UInt16 = 0x8C2C
private let configureTransactionId: UInt16 = 0x8C2D

private let pairTarget: UInt16 = 0x0702
private let stopStreamingTarget: UInt16 = 0x0802
private let preparingToLivestreamTarget: UInt16 = 0x0802
private let setupWifiTarget: UInt16 = 0x0702
private let configureTarget: UInt16 = 0x0102
private let startStreamingTarget: UInt16 = 0x0802

private let pairType: UInt32 = 0x450740
private let stopStreamingType: UInt32 = 0x8E0240
private let preparingToLivestreamType: UInt32 = 0xE10240
private let setupWifiType: UInt32 = 0x470740
private let configureType: UInt32 = 0x8E0240
private let startStreamingType: UInt32 = 0x780840

private let fff4Id = CBUUID(string: "FFF4")
private let fff5Id = CBUUID(string: "FFF5")

private let pairPinCode = "mbln"

enum DjiDeviceState {
    case idle
    case discovering
    case connecting
    case checkingIfPaired
    case pairing
    case cleaningUp
    case preparingStream
    case settingUpWifi
    case wifiSetupFailed
    case configuring
    case startingStream
    case streaming
    case stoppingStream
}

protocol DjiDeviceDelegate: AnyObject {
    func djiDeviceStreamingState(_ device: DjiDevice, state: DjiDeviceState)
}

class DjiDevice: NSObject {
    private var wifiSsid: String?
    private var wifiPassword: String?
    private var rtmpUrl: String?
    private var resolution: SettingsDjiDeviceResolution?
    private var fps: Int = 30
    private var bitrate: UInt32 = 6_000_000
    private var imageStabilization: SettingsDjiDeviceImageStabilization?
    private var deviceId: UUID?
    private var centralManager: CBCentralManager?
    private var cameraPeripheral: CBPeripheral?
    private var fff5Characteristic: CBCharacteristic?
    private var state: DjiDeviceState = .idle
    weak var delegate: (any DjiDeviceDelegate)?
    private var startStreamingTimer: DispatchSourceTimer?
    private var stopStreamingTimer: DispatchSourceTimer?
    private var model: SettingsDjiDeviceModel = .unknown
    // periphery:ignore
    private var batteryPercentage: UInt8?

    func startLiveStream(
        wifiSsid: String,
        wifiPassword: String,
        rtmpUrl: String,
        resolution: SettingsDjiDeviceResolution,
        fps: Int,
        bitrate: UInt32,
        imageStabilization: SettingsDjiDeviceImageStabilization,
        deviceId: UUID,
        model: SettingsDjiDeviceModel
    ) {
        logger.info("dji-device: Start live stream for \(model)")
        self.wifiSsid = wifiSsid
        self.wifiPassword = wifiPassword
        self.rtmpUrl = rtmpUrl
        self.resolution = resolution
        self.fps = fps
        self.bitrate = bitrate
        self.imageStabilization = imageStabilization
        self.deviceId = deviceId
        self.model = model
        reset()
        startStartStreamingTimer()
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stopLiveStream() {
        guard state != .idle else {
            return
        }
        logger.info("dji-device: Stop live stream")
        stopStartStreamingTimer()
        startStopStreamingTimer()
        sendStopStream()
        setState(state: .stoppingStream)
    }

    private func reset() {
        stopStartStreamingTimer()
        stopStopStreamingTimer()
        centralManager = nil
        cameraPeripheral = nil
        fff5Characteristic = nil
        batteryPercentage = nil
        setState(state: .idle)
    }

    private func startStartStreamingTimer() {
        startStreamingTimer = DispatchSource.makeTimerSource(queue: .main)
        startStreamingTimer!.schedule(deadline: .now() + 60)
        startStreamingTimer!.setEventHandler { [weak self] in
            self?.startStreamingTimerExpired()
        }
        startStreamingTimer!.activate()
    }

    private func stopStartStreamingTimer() {
        startStreamingTimer?.cancel()
        startStreamingTimer = nil
    }

    private func startStreamingTimerExpired() {
        reset()
    }

    private func startStopStreamingTimer() {
        stopStreamingTimer = DispatchSource.makeTimerSource(queue: .main)
        stopStreamingTimer!.schedule(deadline: .now() + 10)
        stopStreamingTimer!.setEventHandler { [weak self] in
            self?.stopStreamingTimerExpired()
        }
        stopStreamingTimer!.activate()
    }

    private func stopStopStreamingTimer() {
        stopStreamingTimer?.cancel()
        stopStreamingTimer = nil
    }

    private func stopStreamingTimerExpired() {
        reset()
    }

    private func setState(state: DjiDeviceState) {
        guard state != self.state else {
            return
        }
        logger.info("dji-device: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.djiDeviceStreamingState(self, state: state)
    }

    func getState() -> DjiDeviceState {
        return state
    }
}

extension DjiDevice: CBCentralManagerDelegate {
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
        cameraPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        startStartStreamingTimer()
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {}

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("dji-device: Connected")
        peripheral.discoverServices(nil)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
        logger.info("dji-device: Disconnected")
        reset()
    }
}

extension DjiDevice: CBPeripheralDelegate {
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
            logger.info("dji-device: Discarding corrupt message \(value.hexString())")
            return
        }
        switch state {
        case .checkingIfPaired:
            processCheckingIfPaired(response: message)
        case .pairing:
            processPairing()
        case .cleaningUp:
            processCleaningUp(response: message)
        case .preparingStream:
            processPreparingStream(response: message)
        case .settingUpWifi:
            processSettingUpWifi(response: message)
        case .configuring:
            processConfiguring(response: message)
        case .startingStream:
            processStartingStream(response: message)
        case .streaming:
            processStreaming(message: message)
        case .stoppingStream:
            processStoppingStream(response: message)
        default:
            logger.info("dji-device: Received message in unexpected state '\(state)'")
        }
    }

    private func sendStopStream() {
        let payload = DjiStopStreamingMessagePayload()
        writeMessage(message: DjiMessage(target: stopStreamingTarget,
                                         id: stopStreamingTransactionId,
                                         type: stopStreamingType,
                                         payload: payload.encode()))
    }

    private func processCheckingIfPaired(response: DjiMessage) {
        guard response.id == pairTransactionId else {
            return
        }
        if response.payload == Data([0, 1]) {
            processPairing()
        } else {
            setState(state: .pairing)
        }
    }

    private func processPairing() {
        sendStopStream()
        setState(state: .cleaningUp)
    }

    private func processCleaningUp(response: DjiMessage) {
        guard response.id == stopStreamingTransactionId else {
            return
        }
        let payload = DjiPreparingToLivestreamMessagePayload()
        writeMessage(message: DjiMessage(target: preparingToLivestreamTarget,
                                         id: preparingToLivestreamTransactionId,
                                         type: preparingToLivestreamType,
                                         payload: payload.encode()))
        setState(state: .preparingStream)
    }

    private func processPreparingStream(response: DjiMessage) {
        guard response.id == preparingToLivestreamTransactionId, let wifiSsid, let wifiPassword else {
            return
        }
        let payload = DjiSetupWifiMessagePayload(wifiSsid: wifiSsid, wifiPassword: wifiPassword)
        writeMessage(message: DjiMessage(target: setupWifiTarget,
                                         id: setupWifiTransactionId,
                                         type: setupWifiType,
                                         payload: payload.encode()))
        setState(state: .settingUpWifi)
    }

    private func processSettingUpWifi(response: DjiMessage) {
        guard response.id == setupWifiTransactionId else {
            return
        }
        guard response.payload == Data([0x00, 0x00]) else {
            reset()
            setState(state: .wifiSetupFailed)
            return
        }
        switch model {
        case .osmoAction3:
            sendStartStreaming()
        case .osmoAction4:
            guard let imageStabilization else {
                return
            }
            let payload = DjiConfigureMessagePayload(imageStabilization: imageStabilization)
            writeMessage(message: DjiMessage(target: configureTarget,
                                             id: configureTransactionId,
                                             type: configureType,
                                             payload: payload.encode()))
            setState(state: .configuring)
        case .osmoPocket3:
            sendStartStreaming()
        case .unknown:
            sendStartStreaming()
        }
    }

    private func processConfiguring(response: DjiMessage) {
        guard response.id == configureTransactionId else {
            return
        }
        sendStartStreaming()
    }

    private func sendStartStreaming() {
        guard let rtmpUrl, let resolution else {
            return
        }
        let payload = DjiStartStreamingMessagePayload(
            rtmpUrl: rtmpUrl,
            resolution: resolution,
            fps: fps,
            bitrateKbps: UInt16((bitrate / 1000) & 0xFFFF)
        )
        writeMessage(message: DjiMessage(target: startStreamingTarget,
                                         id: startStreamingTransactionId,
                                         type: startStreamingType,
                                         payload: payload.encode()))
        setState(state: .startingStream)
    }

    private func processStartingStream(response: DjiMessage) {
        guard response.id == startStreamingTransactionId else {
            return
        }
        setState(state: .streaming)
        stopStartStreamingTimer()
    }

    private func processStreaming(message: DjiMessage) {
        switch message.type {
        case 0x020D00:
            guard message.payload.count >= 21 else {
                return
            }
            batteryPercentage = message.payload[20]
        default:
            break
        }
    }

    private func processStoppingStream(response: DjiMessage) {
        guard response.id == stopStreamingTransactionId else {
            return
        }
        reset()
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
        guard state == .connecting else {
            return
        }
        guard characteristic.uuid == fff4Id else {
            return
        }
        let payload = DjiPairMessagePayload(pairPinCode: pairPinCode)
        let request = DjiMessage(
            target: pairTarget,
            id: pairTransactionId,
            type: pairType,
            payload: payload.encode()
        )
        writeMessage(message: request)
        setState(state: .checkingIfPaired)
    }

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {}
}
