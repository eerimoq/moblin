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
    private var supportedLenses: [UInt64]?
    private var deviceId: UUID?
    private var centralManager: CBCentralManager?
    private var cameraPeripheral: CBPeripheral?
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
    private var scanId: UInt64?
    private var scanTotalEntries: UInt64 = 0
    private var scanFetchedEntries: UInt64 = 0
    private var scanMatch: GoProScanEntry?

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
        logger.info(
            "gopro-device: [start] Camera \(deviceId), WiFi \(wifiSsid), \(resolution.rawValue), "
                + "\(bitrate / 1000) kbps, lens \(lens.rawValue)"
        )
        self.wifiSsid = wifiSsid
        self.wifiPassword = wifiPassword
        self.rtmpUrl = rtmpUrl
        self.resolution = resolution
        self.bitrate = bitrate
        self.lens = lens
        self.deviceId = deviceId
        resetConnection()
        setState(.discovering)
        operationTimeoutTimer.startSingleShot(timeout: 90) { [weak self] in
            self?.fail(message: "Timed out while starting live stream")
        }
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stopLiveStream() {
        guard state != .idle else {
            return
        }
        logger.info("gopro-device: [stop] Stop requested in state \(state)")
        operationTimeoutTimer.stop()
        statusPollTimer.stop()
        startShutterTimer.stop()
        let wasStreaming = state == .startingStream || state == .streaming
        setState(.stoppingStream)
        if wasStreaming, characteristics[GoProBleUuid.command] != nil {
            send(GoProBleProtocol.setShutter(on: false), to: GoProBleUuid.command)
            stopTimer.startSingleShot(timeout: 8) { [weak self] in
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
        logger.info("gopro-device: [cleanup] Reset BLE connection and timers")
        operationTimeoutTimer.stop()
        wifiTimeoutTimer.stop()
        pairingFallbackTimer.stop()
        statusPollTimer.stop()
        startShutterTimer.stop()
        stopTimer.stop()
        keepAliveTimer.stop()
        if let cameraPeripheral {
            centralManager?.cancelPeripheralConnection(cameraPeripheral)
        }
        centralManager = nil
        cameraPeripheral = nil
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
        setState(.idle)
    }

    private func fail(message: String, state: GoProDeviceState = .failed) {
        logger.info("gopro-device: [failed] \(message)")
        resetConnection()
        setState(state)
    }

    private func setState(_ state: GoProDeviceState) {
        guard self.state != state else {
            return
        }
        logger.info("gopro-device: [state] \(self.state) -> \(state)")
        self.state = state
        delegate?.goProDeviceStreamingState(self, state: state)
    }

    private func beginGoProSetup() {
        guard !didBeginSetup else {
            return
        }
        didBeginSetup = true
        logger.info("gopro-device: [setup] Required characteristics and notifications are ready")
        keepAliveTimer.startPeriodic(interval: 3) { [weak self] in
            self?.sendKeepAlive()
        }
        setState(.pairing)
        logger.info("gopro-device: [pairing] Sending pairing-complete request")
        send(GoProBleProtocol.setPairingComplete(), to: GoProBleUuid.networkManagement)
        pairingFallbackTimer.startSingleShot(timeout: 1) { [weak self] in
            self?.startWifiScan()
        }
    }

    private func startWifiScan() {
        guard state == .pairing else {
            return
        }
        pairingFallbackTimer.stop()
        setState(.settingUpWifi)
        scanId = nil
        scanTotalEntries = 0
        scanFetchedEntries = 0
        scanMatch = nil
        logger.info("gopro-device: [wifi] Asking camera to scan for \"\(wifiSsid)\"")
        send(GoProBleProtocol.startScan(), to: GoProBleUuid.networkManagement)
        wifiTimeoutTimer.startSingleShot(timeout: 30) { [weak self] in
            self?.fail(message: "Timed out scanning for WiFi networks", state: .wifiSetupFailed)
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
        let remaining = scanTotalEntries - scanFetchedEntries
        logger.info(
            "gopro-device: [wifi] Requesting access points \(scanFetchedEntries) to "
                + "\(scanTotalEntries) of scan \(scanId)"
        )
        send(
            GoProBleProtocol.getApEntries(
                scanId: scanId,
                startIndex: scanFetchedEntries,
                maximumEntries: min(remaining, 100)
            ),
            to: GoProBleUuid.networkManagement
        )
    }

    private func connectToScannedWifi() {
        guard let scanMatch else {
            fail(
                message: "The camera did not find \(wifiSsid) among \(scanFetchedEntries) access point(s). "
                    + "GoPro cameras only support 2.4 GHz networks.",
                state: .wifiSetupFailed
            )
            return
        }
        guard !scanMatch.isUnsupportedType else {
            fail(
                message: "The camera does not support the security type of \(wifiSsid). Use WPA2.",
                state: .wifiSetupFailed
            )
            return
        }
        if scanMatch.isConfigured {
            logger.info("gopro-device: [wifi] Connecting to already provisioned \(wifiSsid)")
            send(
                GoProBleProtocol.connectToProvisionedWifi(ssid: wifiSsid),
                to: GoProBleUuid.networkManagement
            )
        } else {
            logger.info("gopro-device: [wifi] Asking camera to connect to \(wifiSsid)")
            send(
                GoProBleProtocol.connectToWifi(ssid: wifiSsid, password: wifiPassword),
                to: GoProBleUuid.networkManagement
            )
        }
    }

    private func configureLiveStream() {
        guard state == .settingUpWifi else {
            return
        }
        wifiTimeoutTimer.stop()
        setState(.configuring)
        logger.info("gopro-device: [livestream] WiFi connected; registering for livestream status")
        send(GoProBleProtocol.registerLiveStreamStatus(), to: GoProBleUuid.query)
        waitingForShutterOffBeforeConfigure = true
        logger.info("gopro-device: [shutter] Ensuring shutter is off before configuration")
        send(GoProBleProtocol.setShutter(on: false), to: GoProBleUuid.command)
    }

    private func sendLiveStreamConfiguration() {
        var lens = lens
        if let lensValue = lens.protobufValue, let supportedLenses, !supportedLenses.contains(lensValue) {
            logger.info(
                "gopro-device: [livestream] Camera does not support \(lens.rawValue) lens; using default"
            )
            lens = .auto
        }
        logger.info("gopro-device: [livestream] Sending livestream configuration, \(lens.rawValue) lens")
        send(
            GoProBleProtocol.setLiveStreamMode(
                url: rtmpUrl,
                resolution: resolution,
                bitrate: bitrate,
                lens: lens
            ),
            to: GoProBleUuid.command
        )
        statusPollTimer.startPeriodic(interval: 1, initial: 1) { [weak self] in
            self?.send(GoProBleProtocol.getLiveStreamStatus(), to: GoProBleUuid.query)
        }
    }

    private func startShutterWhenReady() {
        guard state == .configuring, !didScheduleShutterStart else {
            return
        }
        didScheduleShutterStart = true
        setState(.startingStream)
        logger.info("gopro-device: [livestream] Camera is ready; starting shutter in 2 seconds")
        startShutterTimer.startSingleShot(timeout: 2) { [weak self] in
            logger.info("gopro-device: [shutter] Sending shutter-on request")
            self?.send(GoProBleProtocol.setShutter(on: true), to: GoProBleUuid.command)
        }
    }

    private func sendKeepAlive() {
        guard characteristics[GoProBleUuid.settings] != nil else {
            return
        }
        send(GoProBleProtocol.keepAlive(), to: GoProBleUuid.settings)
        keepAliveCount += 1
        if state == .streaming, keepAliveCount.isMultiple(of: 10) {
            send(GoProBleProtocol.getBatteryPercentage(), to: GoProBleUuid.query)
        }
    }

    private func send(_ payload: Data, to characteristicId: CBUUID) {
        guard let characteristic = characteristics[characteristicId] else {
            logger.info("gopro-device: Missing characteristic \(characteristicId)")
            return
        }
        let packets = GoProBleProtocol.packets(for: payload)
        logger.info(
            "gopro-device: [ble-send] \(describePayload(payload, characteristic: characteristicId)); "
                + "\(payload.count) bytes in \(packets.count) packet(s)"
        )
        for packet in packets {
            pendingWrites.append((characteristic, packet))
        }
        writeNextPacketIfNeeded()
    }

    private func writeNextPacketIfNeeded() {
        guard !writeInProgress, let next = pendingWrites.first, let cameraPeripheral else {
            return
        }
        writeInProgress = true
        cameraPeripheral.writeValue(next.packet, for: next.characteristic, type: .withResponse)
    }

    private func processMessage(_ message: Data, from characteristic: CBUUID) {
        logger.info(
            "gopro-device: [ble-receive] \(characteristicName(characteristic)): \(message.hexString())"
        )
        if characteristic == GoProBleUuid.networkManagementResponse {
            processNetworkMessage(message)
        } else if characteristic == GoProBleUuid.commandResponse {
            processCommandMessage(message)
        } else if characteristic == GoProBleUuid.queryResponse {
            processQueryMessage(message)
        }
    }

    private func processNetworkMessage(_ message: Data) {
        guard message.count >= 2 else {
            return
        }
        let feature = message[0]
        let action = message[1]
        let protobuf = Data(message.dropFirst(2))
        switch (feature, action) {
        case (0x03, 0x81):
            logger.info("gopro-device: [pairing] Pairing-complete response received")
            startWifiScan()
        case (0x02, 0x82):
            handleScanResponse(protobuf)
        case (0x02, 0x0B):
            handleScanningState(
                GoProBleProtocol.protobufVarint(field: 1, in: protobuf),
                scanId: GoProBleProtocol.protobufVarint(field: 2, in: protobuf),
                totalEntries: GoProBleProtocol.protobufVarint(field: 3, in: protobuf)
            )
        case (0x02, 0x83):
            handleApEntries(protobuf)
        case (0x02, 0x84), (0x02, 0x85):
            handleConnectResponse(protobuf)
        case (0x02, 0x0C):
            let provisioningState = GoProBleProtocol.protobufVarint(field: 1, in: protobuf)
            logger.info("gopro-device: [wifi] Provisioning state \(provisioningStateName(provisioningState))")
            handleProvisioningState(provisioningState)
        default:
            logger.info(
                "gopro-device: [network] Ignoring feature 0x\(String(feature, radix: 16)), "
                    + "action 0x\(String(action, radix: 16)), payload \(protobuf.hexString())"
            )
        }
    }

    private func handleScanResponse(_ protobuf: Data) {
        let result = GoProBleProtocol.protobufVarint(field: 1, in: protobuf)
        let scanningState = GoProBleProtocol.protobufVarint(field: 2, in: protobuf)
        logger.info(
            "gopro-device: [wifi] Scan response result \(result ?? 0), state "
                + "\(scanningStateName(scanningState))"
        )
        if result != 1 {
            fail(message: "WiFi scan request failed with result \(result ?? 0)", state: .wifiSetupFailed)
        }
    }

    private func handleConnectResponse(_ protobuf: Data) {
        let result = GoProBleProtocol.protobufVarint(field: 1, in: protobuf)
        let provisioningState = GoProBleProtocol.protobufVarint(field: 2, in: protobuf)
        let timeoutSeconds = GoProBleProtocol.protobufVarint(field: 3, in: protobuf) ?? 20
        logger.info(
            "gopro-device: [wifi] Connect response result \(result ?? 0), state "
                + "\(provisioningStateName(provisioningState)), timeout \(timeoutSeconds)s"
        )
        guard result == 1 else {
            fail(
                message: "WiFi provisioning request failed with result \(result ?? 0)",
                state: .wifiSetupFailed
            )
            return
        }
        wifiTimeoutTimer.startSingleShot(timeout: Double(timeoutSeconds) + 5) { [weak self] in
            guard let self else {
                return
            }
            fail(
                message: "The camera never reported joining \(wifiSsid). "
                    + "Check that it is 2.4 GHz, WPA2 and that the password is correct.",
                state: .wifiSetupFailed
            )
        }
        handleProvisioningState(provisioningState)
    }

    private func handleScanningState(_ scanningState: UInt64?, scanId: UInt64?, totalEntries: UInt64?) {
        logger.info(
            "gopro-device: [wifi] Scanning state \(scanningStateName(scanningState)), "
                + "scan id \(scanId ?? 0), \(totalEntries ?? 0) access point(s)"
        )
        guard state == .settingUpWifi else {
            return
        }
        switch scanningState {
        case 5:
            guard self.scanId == nil else {
                return
            }
            guard let scanId, let totalEntries, totalEntries > 0 else {
                fail(message: "The camera did not find any WiFi networks", state: .wifiSetupFailed)
                return
            }
            self.scanId = scanId
            scanTotalEntries = totalEntries
            scanFetchedEntries = 0
            requestNextApEntries()
        case 3, 4:
            fail(
                message: "WiFi scan failed with state \(scanningStateName(scanningState))",
                state: .wifiSetupFailed
            )
        default:
            break
        }
    }

    private func handleApEntries(_ protobuf: Data) {
        guard state == .settingUpWifi, scanId != nil else {
            return
        }
        let result = GoProBleProtocol.protobufVarint(field: 1, in: protobuf)
        let entries = GoProBleProtocol.scanEntries(in: protobuf)
        logger.info(
            "gopro-device: [wifi] Access points response result \(result ?? 0), \(entries.count) entries"
        )
        guard result == 1 else {
            fail(
                message: "Failed to read WiFi scan results with result \(result ?? 0)",
                state: .wifiSetupFailed
            )
            return
        }
        for entry in entries {
            logger.info(
                "gopro-device: [wifi] Found \"\(entry.ssid)\" at \(entry.signalFrequencyMhz) MHz, "
                    + "\(entry.signalStrengthBars) bar(s), flags \(entry.flagsDescription)"
            )
            if entry.ssid == wifiSsid, scanMatch == nil {
                scanMatch = entry
            }
        }
        scanFetchedEntries += UInt64(entries.count)
        if scanMatch != nil || entries.isEmpty {
            connectToScannedWifi()
        } else {
            requestNextApEntries()
        }
    }

    private func handleProvisioningState(_ provisioningState: UInt64?) {
        switch provisioningState {
        case 5, 6:
            configureLiveStream()
        case 3, 4, 7, 8, 9, 10, 11:
            fail(
                message: "WiFi provisioning failed with state \(provisioningStateName(provisioningState))",
                state: .wifiSetupFailed
            )
        default:
            break
        }
    }

    private func processCommandMessage(_ message: Data) {
        guard message.count >= 2 else {
            return
        }
        if message[0] == 0xF1, message[1] == 0xF9 {
            let protobuf = Data(message.dropFirst(2))
            let result = GoProBleProtocol.protobufVarint(field: 1, in: protobuf)
            logger.info("gopro-device: [livestream] Configuration response result \(result ?? 0)")
            if result != 1 {
                fail(message: "Live stream configuration failed with result \(result ?? 0)")
            }
        } else if message[0] == 0x01 {
            let status = message[1]
            logger.info("gopro-device: [shutter] Response status \(status) in state \(state)")
            guard status == 0 else {
                if state == .configuring, waitingForShutterOffBeforeConfigure {
                    logger.info("gopro-device: [shutter] Shutter-off failed; continuing configuration")
                    waitingForShutterOffBeforeConfigure = false
                    sendLiveStreamConfiguration()
                } else if state == .stoppingStream {
                    logger.info("gopro-device: [shutter] Shutter-off failed while stopping; cleaning up")
                    reset()
                } else {
                    fail(message: "Shutter command failed with status \(status)")
                }
                return
            }
            if state == .configuring, waitingForShutterOffBeforeConfigure {
                waitingForShutterOffBeforeConfigure = false
                sendLiveStreamConfiguration()
            } else if state == .stoppingStream {
                reset()
            }
        }
    }

    private func processQueryMessage(_ message: Data) {
        guard message.count >= 2 else {
            return
        }
        if message[0] == 0xF5, message[1] == 0xF4 || message[1] == 0xF5 {
            let protobuf = Data(message.dropFirst(2))
            if message[1] == 0xF4 {
                handleLiveStreamCapabilities(protobuf)
            }
            handleLiveStreamStatus(GoProBleProtocol.protobufVarint(field: 1, in: protobuf))
        } else if message[0] == 0x13, message[1] == 0, message.count >= 5,
                  message[2] == 0x46, message[3] >= 1
        {
            batteryPercentage = Int(message[4])
        }
    }

    private func handleLiveStreamCapabilities(_ protobuf: Data) {
        guard supportedLenses == nil else {
            return
        }
        let windowSizes = GoProBleProtocol.protobufVarints(field: 5, in: protobuf)
        let lensSupported = GoProBleProtocol.protobufVarint(field: 10, in: protobuf) == 1
        let lenses = lensSupported ? GoProBleProtocol.protobufVarints(field: 11, in: protobuf) : []
        let minimumBitrate = GoProBleProtocol.protobufVarint(field: 8, in: protobuf) ?? 0
        let maximumBitrate = GoProBleProtocol.protobufVarint(field: 9, in: protobuf) ?? 0
        logger.info(
            "gopro-device: [livestream] Camera supports resolutions \(windowSizes), lenses \(lenses), "
                + "bitrate \(minimumBitrate)-\(maximumBitrate) kbps"
        )
        supportedLenses = lenses
    }

    private func handleLiveStreamStatus(_ liveStreamStatus: UInt64?) {
        logger.info("gopro-device: [livestream] Status \(liveStreamStatusName(liveStreamStatus))")
        switch liveStreamStatus {
        case 2:
            startShutterWhenReady()
        case 3, 6:
            setState(.streaming)
            operationTimeoutTimer.stop()
            statusPollTimer.stop()
            send(GoProBleProtocol.getBatteryPercentage(), to: GoProBleUuid.query)
        case 0, 4:
            if state == .stoppingStream {
                reset()
            }
        case 5, 7:
            fail(message: "Camera reported live stream failure")
        default:
            break
        }
    }

    private func provisioningStateName(_ value: UInt64?) -> String {
        switch value {
        case 0: "unknown (0)"
        case 1: "never started (1)"
        case 2: "started (2)"
        case 3: "aborted by system (3)"
        case 4: "cancelled by user (4)"
        case 5: "success, new network (5)"
        case 6: "success, saved network (6)"
        case 7: "failed to associate (7)"
        case 8: "password authentication failed (8)"
        case 9: "EULA blocking (9)"
        case 10: "no internet (10)"
        case 11: "unsupported network type (11)"
        default: "missing"
        }
    }

    private func scanningStateName(_ value: UInt64?) -> String {
        switch value {
        case 0: "unknown (0)"
        case 1: "never started (1)"
        case 2: "started (2)"
        case 3: "aborted by system (3)"
        case 4: "cancelled by user (4)"
        case 5: "success (5)"
        default: "missing"
        }
    }

    private func liveStreamStatusName(_ value: UInt64?) -> String {
        switch value {
        case 0: "idle (0)"
        case 1: "config (1)"
        case 2: "ready (2)"
        case 3: "streaming (3)"
        case 4: "complete (4)"
        case 5: "failed (5)"
        case 6: "reconnecting (6)"
        case 7: "unavailable (7)"
        default: "unknown (\(value.map(String.init) ?? "missing"))"
        }
    }

    private func characteristicName(_ uuid: CBUUID) -> String {
        switch uuid {
        case GoProBleUuid.command: "command"
        case GoProBleUuid.commandResponse: "command response"
        case GoProBleUuid.settings: "settings"
        case GoProBleUuid.settingsResponse: "settings response"
        case GoProBleUuid.query: "query"
        case GoProBleUuid.queryResponse: "query response"
        case GoProBleUuid.networkManagement: "network management"
        case GoProBleUuid.networkManagementResponse: "network management response"
        default: uuid.uuidString
        }
    }

    private func describePayload(_ payload: Data, characteristic: CBUUID) -> String {
        if characteristic == GoProBleUuid.networkManagement, payload.count >= 2 {
            return "network feature 0x\(String(payload[0], radix: 16)), action 0x\(String(payload[1], radix: 16))"
        } else if characteristic == GoProBleUuid.command, let command = payload.first {
            if command == 0x01, payload.count >= 3 {
                return "shutter \(payload[2] == 0 ? "off" : "on")"
            }
            return "command 0x\(String(command, radix: 16))"
        } else if characteristic == GoProBleUuid.query, payload.count >= 2 {
            return "query 0x\(String(payload[0], radix: 16))/0x\(String(payload[1], radix: 16))"
        } else if characteristic == GoProBleUuid.settings, let setting = payload.first {
            return "setting 0x\(String(setting, radix: 16))"
        }
        return characteristicName(characteristic)
    }
}

extension GoProDevice: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("gopro-device: [bluetooth] Central state \(central.state.rawValue)")
        guard central.state == .poweredOn else {
            if central.state != .unknown, central.state != .resetting {
                fail(message: "Bluetooth is not available")
            }
            return
        }
        guard let deviceId,
              let peripheral = central.retrievePeripherals(withIdentifiers: [deviceId]).first
        else {
            fail(message: "Camera not found. Pair it from GoPro settings first.")
            return
        }
        cameraPeripheral = peripheral
        peripheral.delegate = self
        setState(.connecting)
        logger
            .info(
                "gopro-device: [bluetooth] Connecting to \(peripheral.name ?? "GoPro") (\(peripheral.identifier))"
            )
        central.connect(peripheral)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error: (any Error)?) {
        let message = error?.localizedDescription ?? "Unknown error"
        fail(message: "Failed to connect: \(message)")
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("gopro-device: [bluetooth] Connected; discovering services")
        peripheral.discoverServices([GoProBleUuid.controlService, GoProBleUuid.cameraManagementService])
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error: (any Error)?) {
        logger.info(
            "gopro-device: [bluetooth] Disconnected in state \(state): "
                + "\(error?.localizedDescription ?? "no error")"
        )
        if state != .idle, state != .failed, state != .wifiSetupFailed {
            let message = error?.localizedDescription ?? "Unknown error"
            fail(message: "Camera disconnected: \(message)")
        }
    }
}

extension GoProDevice: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard error == nil else {
            fail(message: "Failed to discover GoPro services")
            return
        }
        logger.info("gopro-device: [bluetooth] Discovered \(peripheral.services?.count ?? 0) service(s)")
        for service in peripheral.services ?? [] {
            logger.info("gopro-device: [bluetooth] Discovering characteristics for \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        guard error == nil else {
            fail(message: "Failed to discover GoPro characteristics")
            return
        }
        logger.info(
            "gopro-device: [bluetooth] Service \(service.uuid) has "
                + "\(service.characteristics?.count ?? 0) characteristic(s)"
        )
        let notifyIds: Set<CBUUID> = [
            GoProBleUuid.commandResponse,
            GoProBleUuid.settingsResponse,
            GoProBleUuid.queryResponse,
            GoProBleUuid.networkManagementResponse,
        ]
        for characteristic in service.characteristics ?? [] {
            logger.info("gopro-device: [bluetooth] Found characteristic \(characteristic.uuid)")
            characteristics[characteristic.uuid] = characteristic
            if notifyIds.contains(characteristic.uuid) {
                accumulators[characteristic.uuid] = GoProBleMessageAccumulator()
                peripheral.setNotifyValue(true, for: characteristic)
                logger.info("gopro-device: [bluetooth] Subscribing to \(characteristic.uuid)")
            }
        }
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil, characteristic.isNotifying else {
            fail(message: "Failed to subscribe to GoPro notifications")
            return
        }
        subscribedCharacteristics.insert(characteristic.uuid)
        logger.info("gopro-device: [bluetooth] Subscribed to \(characteristic.uuid)")
        let required: Set<CBUUID> = [
            GoProBleUuid.commandResponse,
            GoProBleUuid.queryResponse,
            GoProBleUuid.networkManagementResponse,
        ]
        if required.isSubset(of: subscribedCharacteristics),
           characteristics[GoProBleUuid.command] != nil,
           characteristics[GoProBleUuid.settings] != nil,
           characteristics[GoProBleUuid.query] != nil,
           characteristics[GoProBleUuid.networkManagement] != nil
        {
            beginGoProSetup()
        }
    }

    func peripheral(
        _: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if let error {
            logger.info(
                "gopro-device: [ble-receive] Failed on \(characteristic.uuid): \(error.localizedDescription)"
            )
            return
        }
        guard let packet = characteristic.value,
              let message = accumulators[characteristic.uuid]?.append(packet: packet)
        else {
            return
        }
        processMessage(message, from: characteristic.uuid)
    }

    func peripheral(
        _: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        writeInProgress = false
        guard error == nil else {
            fail(
                message: "Failed to write \(characteristic.uuid): \(error?.localizedDescription ?? "unknown error")"
            )
            return
        }
        logger.info("gopro-device: [ble-write] Packet accepted on \(characteristic.uuid)")
        if !pendingWrites.isEmpty {
            pendingWrites.removeFirst()
        }
        writeNextPacketIfNeeded()
    }
}
