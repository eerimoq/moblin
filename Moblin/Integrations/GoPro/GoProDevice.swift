@preconcurrency import CoreBluetooth
import Foundation

enum GoProDeviceState: Equatable {
    case idle
    case discovering
    case connecting
    case pairing
    case settingUpWifi
    case wifiSetupFailed
    case configuring
    case startingStream
    case streaming
    case stoppingStream
    case failed
}

private let startLiveStreamTimeout = 90.0
private let stopLiveStreamTimeout = 8.0
private let keepAliveInterval = 3.0
private let pairingFallbackTimeout = 1.0
private let wifiScanTimeout = 30.0
private let wifiProvisioningDefaultTimeout: Int32 = 20
private let wifiProvisioningTimeoutMargin = 5.0
private let statusPollInterval = 1.0
private let startShutterDelay = 2.0
private let batteryPollKeepAlives = 10

protocol GoProDeviceDelegate: AnyObject {
    func goProDeviceStreamingState(_ device: GoProDevice, state: GoProDeviceState)
}

final class GoProDevice: NSObject {
    weak var delegate: (any GoProDeviceDelegate)?

    private var wifiSsid = ""
    private var wifiPassword = ""
    private var rtmpUrl = ""
    private var resolution: SettingsGoProLaunchLiveStreamResolution = .r1080p
    private var bitrate: UInt32 = 6_000_000
    private var lens: SettingsGoProLens = .auto
    private var deviceId: UUID?
    private var centralManager: CBCentralManager?
    private var devicePeripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    private var subscribedCharacteristics: Set<CBUUID> = []
    private var accumulators: [CBUUID: GoProBleMessageAccumulator] = [:]
    private var pendingWrites: [(characteristic: CBCharacteristic, packet: Data)] = []
    private var writeInProgress = false
    private var state: GoProDeviceState = .idle
    private var didBeginSetup = false
    private var didScheduleShutterStart = false
    private var waitingForShutterOffBeforeConfigure = false
    private var keepAliveCount = 0
    private var batteryPercentage: Int?
    private var scanId: Int32?
    private var scanTotalEntries: Int32 = 0
    private var scanFetchedEntries: Int32 = 0
    private var scanMatch: OpenGopro_ResponseGetApEntries.ScanEntry?
    private var supportedLenses: [OpenGopro_EnumLens]?

    private let operationTimeoutTimer = SimpleTimer(queue: .main)
    private let wifiTimeoutTimer = SimpleTimer(queue: .main)
    private let pairingFallbackTimer = SimpleTimer(queue: .main)
    private let statusPollTimer = SimpleTimer(queue: .main)
    private let startShutterTimer = SimpleTimer(queue: .main)
    private let stopTimer = SimpleTimer(queue: .main)
    private let keepAliveTimer = SimpleTimer(queue: .main)

    func startLiveStream(
        wifiSsid: String,
        wifiPassword: String,
        rtmpUrl: String,
        resolution: SettingsGoProLaunchLiveStreamResolution,
        bitrate: UInt32,
        lens: SettingsGoProLens,
        deviceId: UUID
    ) {
        self.wifiSsid = wifiSsid
        self.wifiPassword = wifiPassword
        self.rtmpUrl = rtmpUrl
        self.resolution = resolution
        self.bitrate = bitrate
        self.lens = lens
        self.deviceId = deviceId
        resetConnection()
        setState(state: .discovering)
        operationTimeoutTimer.startSingleShot(timeout: startLiveStreamTimeout) { [weak self] in
            self?.fail()
        }
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stopLiveStream() {
        guard state != .idle else {
            return
        }
        operationTimeoutTimer.stop()
        statusPollTimer.stop()
        startShutterTimer.stop()
        let wasStreaming = state == .startingStream || state == .streaming
        setState(state: .stoppingStream)
        if wasStreaming, characteristics[goProCommandId] != nil {
            send(goProSetShutterMessage(on: false), to: goProCommandId)
            stopTimer.startSingleShot(timeout: stopLiveStreamTimeout) { [weak self] in
                self?.reset()
            }
        } else {
            reset()
        }
    }

    func getState() -> GoProDeviceState {
        state
    }

    func getBatteryPercentage() -> Int? {
        batteryPercentage
    }

    private func resetConnection() {
        operationTimeoutTimer.stop()
        wifiTimeoutTimer.stop()
        pairingFallbackTimer.stop()
        statusPollTimer.stop()
        startShutterTimer.stop()
        stopTimer.stop()
        keepAliveTimer.stop()
        if let devicePeripheral {
            centralManager?.cancelPeripheralConnection(devicePeripheral)
        }
        centralManager = nil
        devicePeripheral = nil
        characteristics.removeAll()
        subscribedCharacteristics.removeAll()
        accumulators.removeAll()
        pendingWrites.removeAll()
        writeInProgress = false
        didBeginSetup = false
        didScheduleShutterStart = false
        waitingForShutterOffBeforeConfigure = false
        keepAliveCount = 0
        batteryPercentage = nil
        scanId = nil
        scanTotalEntries = 0
        scanFetchedEntries = 0
        scanMatch = nil
        supportedLenses = nil
    }

    private func reset() {
        resetConnection()
        setState(state: .idle)
    }

    private func fail(state: GoProDeviceState = .failed) {
        resetConnection()
        setState(state: state)
    }

    private func setState(state: GoProDeviceState) {
        guard self.state != state else {
            return
        }
        self.state = state
        delegate?.goProDeviceStreamingState(self, state: state)
    }

    private func beginSetup() {
        guard !didBeginSetup else {
            return
        }
        didBeginSetup = true
        keepAliveTimer.startPeriodic(interval: keepAliveInterval) { [weak self] in
            self?.sendKeepAlive()
        }
        setState(state: .pairing)
        send(goProPairingCompleteMessage(), to: goProNetworkManagementId)
        pairingFallbackTimer.startSingleShot(timeout: pairingFallbackTimeout) { [weak self] in
            self?.startWifiScan()
        }
    }

    private func startWifiScan() {
        guard state == .pairing else {
            return
        }
        pairingFallbackTimer.stop()
        setState(state: .settingUpWifi)
        send(goProStartScanMessage(), to: goProNetworkManagementId)
        wifiTimeoutTimer.startSingleShot(timeout: wifiScanTimeout) { [weak self] in
            self?.fail(state: .wifiSetupFailed)
        }
    }

    private func requestNextApEntries() {
        guard let scanId else {
            return
        }
        guard scanFetchedEntries < scanTotalEntries else {
            connectToScannedWifi()
            return
        }
        send(
            goProGetApEntriesMessage(
                scanId: scanId,
                startIndex: scanFetchedEntries,
                maximumEntries: min(scanTotalEntries - scanFetchedEntries, goProMaximumApEntriesPerRequest)
            ),
            to: goProNetworkManagementId
        )
    }

    private func connectToScannedWifi() {
        guard let scanMatch else {
            fail(state: .wifiSetupFailed)
            return
        }
        guard !scanMatch.isUnsupportedType() else {
            fail(state: .wifiSetupFailed)
            return
        }
        if scanMatch.isConfigured() {
            send(
                goProConnectToProvisionedWifiMessage(ssid: wifiSsid),
                to: goProNetworkManagementId
            )
        } else {
            send(
                goProConnectToWifiMessage(ssid: wifiSsid, password: wifiPassword),
                to: goProNetworkManagementId
            )
        }
    }

    private func configureLiveStream() {
        guard state == .settingUpWifi else {
            return
        }
        wifiTimeoutTimer.stop()
        setState(state: .configuring)
        send(goProRegisterLiveStreamStatusMessage(), to: goProQueryId)
        waitingForShutterOffBeforeConfigure = true
        send(goProSetShutterMessage(on: false), to: goProCommandId)
    }

    private func sendLiveStreamConfiguration() {
        var lens = lens
        if let lensValue = lens.toProtobuf(), let supportedLenses, !supportedLenses.contains(lensValue) {
            lens = .auto
        }
        send(
            goProSetLiveStreamModeMessage(
                url: rtmpUrl,
                resolution: resolution,
                bitrate: bitrate,
                lens: lens
            ),
            to: goProCommandId
        )
        statusPollTimer
            .startPeriodic(interval: statusPollInterval, initial: statusPollInterval) { [weak self] in
                self?.send(goProGetLiveStreamStatusMessage(), to: goProQueryId)
            }
    }

    private func startShutterWhenReady() {
        guard state == .configuring, !didScheduleShutterStart else {
            return
        }
        didScheduleShutterStart = true
        setState(state: .startingStream)
        startShutterTimer.startSingleShot(timeout: startShutterDelay) { [weak self] in
            self?.send(goProSetShutterMessage(on: true), to: goProCommandId)
        }
    }

    private func sendKeepAlive() {
        guard characteristics[goProSettingsId] != nil else {
            return
        }
        send(goProKeepAliveMessage(), to: goProSettingsId)
        keepAliveCount += 1
        if state == .streaming, keepAliveCount.isMultiple(of: batteryPollKeepAlives) {
            send(goProGetBatteryPercentageMessage(), to: goProQueryId)
        }
    }

    private func send(_ payload: Data, to characteristicId: CBUUID) {
        guard let characteristic = characteristics[characteristicId] else {
            return
        }
        for packet in goProBlePackets(payload: payload) {
            pendingWrites.append((characteristic, packet))
        }
        writeNextPacketIfNeeded()
    }

    private func writeNextPacketIfNeeded() {
        guard !writeInProgress, let next = pendingWrites.first, let devicePeripheral else {
            return
        }
        writeInProgress = true
        devicePeripheral.writeValue(next.packet, for: next.characteristic, type: .withResponse)
    }

    private func processMessage(_ message: Data, from characteristic: CBUUID) {
        guard message.count >= 2 else {
            return
        }
        switch characteristic {
        case goProNetworkManagementResponseId:
            processNetworkMessage(message)
        case goProCommandResponseId:
            processCommandMessage(message)
        case goProQueryResponseId:
            processQueryMessage(message)
        default:
            break
        }
    }

    private func processNetworkMessage(_ message: Data) {
        let payload = Data(message.dropFirst(2))
        switch (message[0], message[1]) {
        case (goProPairingFeatureId, goProPairingFinishResponseId):
            startWifiScan()
        case (goProNetworkFeatureId, goProStartScanResponseId):
            guard let response = try? OpenGopro_ResponseStartScanning(serializedBytes: payload) else {
                return
            }
            if response.result != .resultSuccess {
                fail(state: .wifiSetupFailed)
            }
        case (goProNetworkFeatureId, goProScanningNotificationId):
            guard let notification = try? OpenGopro_NotifStartScanning(serializedBytes: payload) else {
                return
            }
            handleScanningState(notification)
        case (goProNetworkFeatureId, goProGetApEntriesResponseId):
            guard let response = try? OpenGopro_ResponseGetApEntries(serializedBytes: payload) else {
                return
            }
            handleApEntries(response)
        case (goProNetworkFeatureId, goProConnectResponseId),
             (goProNetworkFeatureId, goProConnectNewResponseId):
            guard let response = try? OpenGopro_ResponseConnect(serializedBytes: payload) else {
                return
            }
            handleConnectResponse(response)
        case (goProNetworkFeatureId, goProProvisioningNotificationId):
            guard let notification = try? OpenGopro_NotifProvisioningState(serializedBytes: payload) else {
                return
            }
            handleProvisioningState(notification.provisioningState)
        default:
            break
        }
    }

    private func handleScanningState(_ notification: OpenGopro_NotifStartScanning) {
        guard state == .settingUpWifi else {
            return
        }
        switch notification.scanningState {
        case .scanningSuccess:
            guard scanId == nil else {
                return
            }
            guard notification.totalEntries > 0 else {
                fail(state: .wifiSetupFailed)
                return
            }
            scanId = notification.scanID
            scanTotalEntries = notification.totalEntries
            scanFetchedEntries = 0
            requestNextApEntries()
        case .scanningAbortedBySystem, .scanningCancelledByUser:
            fail(state: .wifiSetupFailed)
        default:
            break
        }
    }

    private func handleApEntries(_ response: OpenGopro_ResponseGetApEntries) {
        guard state == .settingUpWifi, scanId != nil else {
            return
        }
        guard response.result == .resultSuccess else {
            fail(state: .wifiSetupFailed)
            return
        }
        if scanMatch == nil {
            scanMatch = response.entries.first(where: { $0.ssid == wifiSsid })
        }
        scanFetchedEntries += Int32(response.entries.count)
        if scanMatch != nil || response.entries.isEmpty {
            connectToScannedWifi()
        } else {
            requestNextApEntries()
        }
    }

    private func handleConnectResponse(_ response: OpenGopro_ResponseConnect) {
        guard response.result == .resultSuccess else {
            fail(state: .wifiSetupFailed)
            return
        }
        let timeoutSeconds = response.hasTimeoutSeconds ? response
            .timeoutSeconds : wifiProvisioningDefaultTimeout
        wifiTimeoutTimer.startSingleShot(
            timeout: Double(timeoutSeconds) + wifiProvisioningTimeoutMargin
        ) { [weak self] in
            self?.fail(state: .wifiSetupFailed)
        }
        handleProvisioningState(response.provisioningState)
    }

    private func handleProvisioningState(_ provisioningState: OpenGopro_EnumProvisioning) {
        switch provisioningState {
        case .provisioningSuccessNewAp, .provisioningSuccessOldAp:
            configureLiveStream()
        case .provisioningAbortedBySystem,
             .provisioningCancelledByUser,
             .provisioningErrorFailedToAssociate,
             .provisioningErrorPasswordAuth,
             .provisioningErrorEulaBlocking,
             .provisioningErrorNoInternet,
             .provisioningErrorUnsupportedType:
            fail(state: .wifiSetupFailed)
        default:
            break
        }
    }

    private func processCommandMessage(_ message: Data) {
        switch (message[0], message[1]) {
        case (goProLiveStreamCommandFeatureId, goProSetLiveStreamModeResponseId):
            guard let response = try? OpenGopro_ResponseGeneric(serializedBytes: Data(message.dropFirst(2)))
            else {
                return
            }
            if response.result != .resultSuccess {
                fail()
            }
        case (goProShutterCommandId, _):
            handleShutterResponse(status: message[1])
        default:
            break
        }
    }

    private func handleShutterResponse(status: UInt8) {
        if state == .configuring, waitingForShutterOffBeforeConfigure {
            waitingForShutterOffBeforeConfigure = false
            sendLiveStreamConfiguration()
        } else if state == .stoppingStream {
            reset()
        } else if status != goProResponseSuccessStatus {
            fail()
        }
    }

    private func processQueryMessage(_ message: Data) {
        switch (message[0], message[1]) {
        case (goProLiveStreamQueryFeatureId, goProGetLiveStreamStatusResponseId),
             (goProLiveStreamQueryFeatureId, goProLiveStreamStatusNotificationId):
            guard let status =
                try? OpenGopro_NotifyLiveStreamStatus(serializedBytes: Data(message.dropFirst(2)))
            else {
                return
            }
            if message[1] == goProGetLiveStreamStatusResponseId, supportedLenses == nil {
                supportedLenses = status.liveStreamLensSupported ? status.liveStreamLensSupportedArray : []
            }
            handleLiveStreamStatus(status.liveStreamStatus)
        case (goProGetStatusQueryId, goProResponseSuccessStatus)
            where message.count >= 5 && message[2] == goProBatteryPercentageStatusId && message[3] >= 1:
            batteryPercentage = Int(message[4])
        default:
            break
        }
    }

    private func handleLiveStreamStatus(_ liveStreamStatus: OpenGopro_EnumLiveStreamStatus) {
        switch liveStreamStatus {
        case .liveStreamStateReady:
            startShutterWhenReady()
        case .liveStreamStateStreaming, .liveStreamStateReconnecting:
            setState(state: .streaming)
            operationTimeoutTimer.stop()
            statusPollTimer.stop()
            send(goProGetBatteryPercentageMessage(), to: goProQueryId)
        case .liveStreamStateIdle, .liveStreamStateCompleteStayOn:
            if state == .stoppingStream {
                reset()
            }
        case .liveStreamStateFailedStayOn, .liveStreamStateUnavailable:
            fail()
        default:
            break
        }
    }
}

extension GoProDevice: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            if central.state != .unknown, central.state != .resetting {
                fail()
            }
            return
        }
        guard let deviceId,
              let peripheral = central.retrievePeripherals(withIdentifiers: [deviceId]).first
        else {
            fail()
            return
        }
        devicePeripheral = peripheral
        peripheral.delegate = self
        setState(state: .connecting)
        central.connect(peripheral)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: (any Error)?) {
        fail()
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([goProControlServiceId, goProCameraManagementServiceId])
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: (any Error)?) {
        if state != .idle, state != .failed, state != .wifiSetupFailed {
            fail()
        }
    }
}

extension GoProDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard error == nil else {
            fail()
            return
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        guard error == nil else {
            fail()
            return
        }
        let notifyIds: Set<CBUUID> = [
            goProCommandResponseId,
            goProSettingsResponseId,
            goProQueryResponseId,
            goProNetworkManagementResponseId,
        ]
        for characteristic in service.characteristics ?? [] {
            characteristics[characteristic.uuid] = characteristic
            if notifyIds.contains(characteristic.uuid) {
                accumulators[characteristic.uuid] = GoProBleMessageAccumulator()
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil, characteristic.isNotifying else {
            fail()
            return
        }
        subscribedCharacteristics.insert(characteristic.uuid)
        let required: Set<CBUUID> = [
            goProCommandResponseId,
            goProQueryResponseId,
            goProNetworkManagementResponseId,
        ]
        if required.isSubset(of: subscribedCharacteristics),
           characteristics[goProCommandId] != nil,
           characteristics[goProSettingsId] != nil,
           characteristics[goProQueryId] != nil,
           characteristics[goProNetworkManagementId] != nil
        {
            beginSetup()
        }
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil, let packet = characteristic.value,
              let message = accumulators[characteristic.uuid]?.append(packet: packet)
        else {
            return
        }
        processMessage(message, from: characteristic.uuid)
    }

    func peripheral(
        _: CBPeripheral,
        didWriteValueFor _: CBCharacteristic,
        error: (any Error)?
    ) {
        writeInProgress = false
        guard error == nil else {
            fail()
            return
        }
        if !pendingWrites.isEmpty {
            pendingWrites.removeFirst()
        }
        writeNextPacketIfNeeded()
    }
}
