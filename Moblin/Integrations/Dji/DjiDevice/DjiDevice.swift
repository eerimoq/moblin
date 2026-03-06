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
    case rsdkConnecting
    case rsdkWaitingForCamera
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
    private let startStreamingTimer = SimpleTimer(queue: .main)
    private let stopStreamingTimer = SimpleTimer(queue: .main)
    private var model: SettingsDjiDeviceModel = .unknown
    private var batteryPercentage: Int?
    private var rsdkSeq: UInt16 = 0
    private var rsdkDeviceId: UInt32 = 0x1234_5678
    private var rsdkMacAddr = Data([0x38, 0x34, 0x56, 0x78, 0x9A, 0xBC])

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
        logger.debug("dji-device: Start live stream for \(model)")
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
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stopLiveStream() {
        guard state != .idle else {
            return
        }
        logger.debug("dji-device: Stop live stream")
        stopStartStreamingTimer()
        startStopStreamingTimer()
        sendStopStream()
        setState(state: .stoppingStream)
    }

    func getBatteryPercentage() -> Int? {
        return batteryPercentage
    }

    private func reset() {
        stopStartStreamingTimer()
        stopStopStreamingTimer()
        centralManager = nil
        cameraPeripheral = nil
        fff5Characteristic = nil
        batteryPercentage = nil
        rsdkSeq = 0
        setState(state: .idle)
    }

    private func startStartStreamingTimer() {
        startStreamingTimer.startSingleShot(timeout: 60) { [weak self] in
            self?.startStreamingTimerExpired()
        }
    }

    private func stopStartStreamingTimer() {
        startStreamingTimer.stop()
    }

    private func startStreamingTimerExpired() {
        reset()
    }

    private func startStopStreamingTimer() {
        stopStreamingTimer.startSingleShot(timeout: 10) { [weak self] in
            self?.stopStreamingTimerExpired()
        }
    }

    private func stopStopStreamingTimer() {
        stopStreamingTimer.stop()
    }

    private func stopStreamingTimerExpired() {
        reset()
    }

    private func setState(state: DjiDeviceState) {
        guard state != self.state else {
            return
        }
        logger.debug("dji-device: State change \(self.state) -> \(state)")
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
        peripheral.discoverServices(nil)
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
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
        guard !value.isEmpty else {
            return
        }
        if value[0] == 0xAA {
            guard let message = try? DjiRSdkMessage(data: value) else {
                logger.info("dji-device: Discarding corrupt R-SDK message \(value.hexString())")
                return
            }
            // logger.debug("dji-device: Got \(message.format())")
            processRSdkMessage(message: message)
            return
        }
        guard let message = try? DjiMessage(data: value) else {
            logger.info("dji-device: Discarding corrupt message \(value.hexString())")
            return
        }
        // logger.debug("dji-device: Got \(message.format())")
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
        case .osmoAction2, .osmoAction3:
            sendStartStreaming()
        case .osmoAction4:
            guard let imageStabilization else {
                return
            }
            let payload = DjiConfigureMessagePayload(imageStabilization: imageStabilization, oa5: false)
            writeMessage(message: DjiMessage(target: configureTarget,
                                             id: configureTransactionId,
                                             type: configureType,
                                             payload: payload.encode()))
            setState(state: .configuring)
        case .osmoAction5Pro, .osmoAction6, .osmo360:
            guard let imageStabilization else {
                return
            }
            let payload = DjiConfigureMessagePayload(imageStabilization: imageStabilization, oa5: true)
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
            bitrateKbps: UInt16((bitrate / 1000) & 0xFFFF),
            oa5: model.hasNewProtocol()
        )
        writeMessage(message: DjiMessage(target: startStreamingTarget,
                                         id: startStreamingTransactionId,
                                         type: startStreamingType,
                                         payload: payload.encode()))
        // Patch for OA5P: Send the confirmation payload to actually start the stream.
        // This is an exact copy of the stop-streaming command, but the last data-bit in
        // the payload is set to 1 instead of 2.
        // It may probably work fine sending it on all devices, but limiting it to OA5P for now.
        if model.hasNewProtocol() {
            let confirmStartStreamPayload = DjiConfirmStartStreamingMessagePayload()
            writeMessage(message: DjiMessage(target: stopStreamingTarget,
                                             id: stopStreamingTransactionId,
                                             type: stopStreamingType,
                                             payload: confirmStartStreamPayload.encode()))
        }
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
            batteryPercentage = Int(message.payload[20])
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

    private func nextRsdkSeq() -> UInt16 {
        rsdkSeq += 1
        return rsdkSeq
    }

    private func processRSdkMessage(message: DjiRSdkMessage) {
        switch state {
        case .rsdkConnecting:
            processRSdkConnecting(message: message)
        case .rsdkWaitingForCamera:
            processRSdkWaitingForCamera(message: message)
        default:
            break
        }
    }

    private func processRSdkConnecting(message: DjiRSdkMessage) {
        guard message.cmdSet == 0x00, message.cmdId == 0x19 else {
            return
        }
        if message.isResponse {
            if message.payload.count >= 5 {
                let retCode = message.payload[4]
                if retCode != 0 {
                    logger.warning("dji-device: R-SDK connection response error: \(retCode)")
                    sendPairRequest()
                    return
                }
            }
            setState(state: .rsdkWaitingForCamera)
        } else {
            handleRSdkCameraConnectionCommand(message: message)
        }
    }

    private func processRSdkWaitingForCamera(message: DjiRSdkMessage) {
        guard message.cmdSet == 0x00, message.cmdId == 0x19 else {
            return
        }
        if !message.isResponse {
            handleRSdkCameraConnectionCommand(message: message)
        }
    }

    private func handleRSdkCameraConnectionCommand(message: DjiRSdkMessage) {
        guard message.payload.count >= 29 else {
            logger.warning("dji-device: R-SDK camera connection command too short")
            sendPairRequest()
            return
        }
        let reader = ByteReader(data: message.payload)
        // Skip device_id (4 bytes)
        do {
            try reader.skipBytes(4)
        } catch {
            sendPairRequest()
            return
        }
        do {
            // Skip mac_addr_len(1) + mac_addr(16) + fw_version(4) + conidx(1) = 22
            try reader.skipBytes(22)
        } catch {
            sendPairRequest()
            return
        }
        guard let verifyMode = try? reader.readUInt8() else {
            sendPairRequest()
            return
        }
        guard verifyMode == 2 else {
            logger.info("dji-device: R-SDK unexpected verify_mode: \(verifyMode)")
            return
        }
        guard let verifyData = try? reader.readUInt16Le() else {
            sendPairRequest()
            return
        }
        if verifyData == 0 {
            logger.info("dji-device: R-SDK connection approved by camera")
            let responsePayload = DjiRSdkConnectionResponsePayload(
                deviceId: rsdkDeviceId,
                retCode: 0,
                cameraNumber: 0
            )
            let response = DjiRSdkMessage(
                cmdType: 0x20,
                seq: message.seq,
                cmdSet: 0x00,
                cmdId: 0x19,
                payload: responsePayload.encode()
            )
            writeRSdkMessage(message: response)
            sendRSdkCameraStatusSubscription()
            sendPairRequest()
        } else {
            logger.warning("dji-device: R-SDK connection rejected by camera")
            sendPairRequest()
        }
    }

    private func sendRSdkConnectionRequest() {
        // Random verification code as per DJI R SDK protocol (matches reference demo)
        let verifyData = UInt16.random(in: 0 ..< 10000)
        let payload = DjiRSdkConnectionRequestPayload(
            deviceId: rsdkDeviceId,
            macAddr: rsdkMacAddr,
            verifyMode: 0,
            verifyData: verifyData
        )
        let message = DjiRSdkMessage(
            cmdType: 0x02,
            seq: nextRsdkSeq(),
            cmdSet: 0x00,
            cmdId: 0x19,
            payload: payload.encode()
        )
        writeRSdkMessage(message: message)
        setState(state: .rsdkConnecting)
    }

    private func sendRSdkCameraStatusSubscription() {
        let payload = DjiRSdkCameraStatusSubscriptionPayload(
            pushMode: 3,
            pushFreq: 20
        )
        let message = DjiRSdkMessage(
            cmdType: 0x00,
            seq: nextRsdkSeq(),
            cmdSet: 0x1D,
            cmdId: 0x05,
            payload: payload.encode()
        )
        writeRSdkMessage(message: message)
    }

    private func sendPairRequest() {
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

    private func writeMessage(message: DjiMessage) {
        logger.debug("dji-device: Send \(message.format())")
        writeValue(value: message.encode())
    }

    private func writeRSdkMessage(message: DjiRSdkMessage) {
        logger.debug("dji-device: Send \(message.format())")
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
        if model.supportsDjiRSdk() {
            sendRSdkConnectionRequest()
        } else {
            sendPairRequest()
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {}
}

extension SettingsDjiDevice {
    func canStartLive() -> Bool {
        if bluetoothPeripheralId == nil {
            return false
        }
        if wifiSsid.isEmpty {
            return false
        }
        switch rtmpUrlType {
        case .server:
            if serverRtmpUrl.isEmpty {
                return false
            }
        case .custom:
            if customRtmpUrl.isEmpty {
                return false
            }
        }
        return true
    }
}
